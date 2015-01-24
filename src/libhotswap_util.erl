%%% libhotswap - Utility Module
%%%
%%% Utility functionality for type conversions and Abstract Syntax Tree 
%%% modification.
%%% 
-module( libhotswap_util ).

-include("libhotswap.hrl").

-export( [check_unsticky/2, funcs/1] ).
-export( [get_ast/1] ).
-export( [ast_to_code/1, ast_by_mfa/2] ).
-export( [fun_to_ast/1, code_to_ast/1] ).
-export( [inject_attributes/2] ).

%% @doc Check if the module is in a sticky directory (as is the case with stdlib
%%   modules). If it is, and you are want to force it, it'll make it unsticky 
%%   for modification by libhotswap. This is dangerous, for very understandable 
%%   reasons as you will have unknown nondeterministic consequences if forced.
%% @end
-spec check_unsticky( atom(), boolean() ) -> ok | error. 
check_unsticky( Module, Force ) -> 
    case {code:is_sticky( Module ), Force} of
        {true, true} ->
            code:unstick_dir(
                filename:dirname( 
                    code:which( Module )));
        {false, _} -> ok;
        _ -> error
    end.

%% @doc Get the AST for the module. It does not require the module's
%%   directory be unsticky, but any modifications pushed to the module will.
%% @end
-spec get_ast( atom() ) -> {ok, ast()} | error.
get_ast( Module ) ->
    case code:get_object_code( Module ) of
        {Module, Binary, _Dir} -> beam_to_ast( Binary );
        error -> error
    end.

%% @doc Convert an Erlang Function into it's AST representation. This is useful
%%   for comparisons or to convert known Erlang source into something the 
%%   compiler can work with during injection. It will also get the ast from
%%   loaded modules if called like:
%%                      fun_to_ast( fun io:nl/0 ).
%% @end
-spec fun_to_ast( fun() ) -> {ok, pfunc()} | {error, badarg | outofscope}.
fun_to_ast( Fun ) -> 
    Tree = erlang:fun_info( Fun ),
    case 
        {proplists:get_value(type,Tree), proplists:get_value(env,Tree)}
    of
        {external, _}  -> ast_by_mfa( build_mfa_from_info(Tree) );
        {internal, Env} ->
            case lists:last( Env ) of
                {[],_,_,Clauses} -> {ok, to_fun( Clauses )};
                _ -> % TODO: Patch AST with values defined out of function scope. 
                    {error, outofscope}
            end
    end.

%% @doc Source code to an Abstract Syntax Tree. Remember to end the source with
%%   a period.
%% @end
-spec code_to_ast( string() ) -> {ok, ast()} | {error, term()}.
code_to_ast( Source ) -> 
    {ok, Ts, _} = erl_scan:string( Source ),
    erl_parse:parse_exprs( Ts ).

%% @doc Given a Func (a fun, function ast, or source code of a function) return
%%   the fun/function it describes. Also has the side effect of verifying the 
%%   value passed in is a function or anonymous fun. 
%% @end.
-spec funcs( func() ) -> {ok, pfunc()} | {error, term()}.
funcs( Func ) when is_function( Func ) -> fun_to_ast( Func );
funcs( Func ) ->
    case io_lib:printable_unicode_list( Func ) of
        true  -> 
            case code_to_ast( Func ) of
                {ok, [Fun]} -> validate_fun_or_function( Fun );
                {ok, [_|_]} -> {error, toomanyexpr};
                {error,_}=E -> E
            end;
        false -> validate_fun_or_function( Func )
    end.

%% @doc Given some Abstract Syntax Tree, get the string representation of it.
-spec ast_to_code( ast() ) -> {ok, string()} | {error, badarg}.
ast_to_code( AST ) ->
    try
        ASTl = case is_list( AST ) of true -> AST; _ -> [AST] end,
        Forms = erl_syntax:form_list( ASTl ),
        String = erl_prettypr:format( Forms ),
        {ok, String}
    catch _:_ -> {error, badarg} end.

%% @doc Given an AST, return the AST for just the function described by the
%%   MFA. It assumes the AST is for the correct moduel. This is used by the 
%%   top-level functionality to highlight the section to get the code/ast for.
%% @end
-spec ast_by_mfa( ast(), mfa() ) -> {ok, pfunc()} | {error, badarg | missing}.
ast_by_mfa( AST, {_,F,A} ) -> 
    case 
       [ T || {function,_,Fun,Arity,_} = T <- AST, Fun==F, Arity==A ]
    of
        []  -> {error, missing};
        [T] -> {ok, T};
        _   -> {error, badarg}
    end.
-spec ast_by_mfa( mfa() ) -> {ok, pfunc()} | 
                             {error, badarg | missing | badmodule}.
ast_by_mfa( {M,_,_}=MFA ) ->
    case get_ast( M ) of
        {ok, AST} -> ast_by_mfa( AST, MFA );
        error     -> {error, badmodule}
    end.

%% @doc Inject attributes such as exports/imports/etc. into the top of the 
%%   module.
%% @end
-spec inject_attributes( [Attr], ast() ) -> {ok, ast()} | {error, badarg}
            when Attr :: {attribute, integer(), atom(), term()}.
inject_attributes( Attributes, FullAST ) ->
    case 
        lists:splitwith( fun({attribute, _,_,_}) -> false; 
                            (_) -> true 
                         end, FullAST )
    of
        {[],_} -> {error, badarg};
        {_,[]} -> {error, badarg};
        {T,B}  -> {ok, T++Attributes++B}
    end.

%% ===========================================================================
%% Internal Translation Tools
%% ===========================================================================

%% @hidden
%% @doc Builds a mfa() object given the result of a call from fun_info. This
%%   assumes the passed in tree is known to be an external function description.
%% @end
build_mfa_from_info( Tree ) ->
    { proplists:get_value( module, Tree ),
      proplists:get_value( name,   Tree ),
      proplists:get_value( arity,  Tree ) }.

%% @hidden
%% @doc Given some BEAM binary, get the Parsed Abstract Syntax Tree 
%%   representation.
%% @end
beam_to_ast( Binary ) ->
    case beam_lib:chunks( Binary, [abstract_code] ) of
        {ok, Ret} -> 
            {_Module, Chunks} = Ret,
            {raw_abstract_v1, AST} = proplists:get_value(abstract_code,Chunks), 
            {ok, AST};
        _ -> {error, badarg}
    end.

%% @hidden
%% @doc Check to make sure the AST is strickly a function/fun.
validate_fun_or_function( {'fun',_,_}=F )          -> {ok, F};
validate_fun_or_function( {'function',_,_,_,_}=F ) -> {ok, F};
validate_fun_or_function( _ )                      -> {error, badarg}. 

%% @hidden
%% @doc Use the syntax_tools to abstract out handmade funs.
to_fun( Clauses ) ->
    SyntaxTree = erl_syntax:fun_expr( Clauses ),
    erl_syntax:revert( SyntaxTree ). % Convert to the erl_parse tree form.

