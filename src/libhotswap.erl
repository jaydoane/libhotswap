-module(libhotswap).

-include("libhotswap.hrl").

-export([vsn/1,version/1,exports/1]).
-export([get_code/1,get_ast/1]).
-export([add_export/2,remove_export/1,rewrite/2]).
-export([inject_in_function/3]).
-export([add_new_clause/3]).

-export_type([ast/0, vsn/0, func/0, pattern/0]).


%% ===========================================================================
%% Misc Ease of Access Functionality
%% ===========================================================================

%% @doc Get the VSN of a loaded module.
-spec vsn( atom() ) -> {ok, pos_integer()} | {error, term()}.
vsn( ModuleName ) when is_atom( ModuleName ) -> 
    MI = erlang:apply( ModuleName, module_info, [] ),
    case 
        catch [ VS || {attributes, As} <- MI, {vsn,[VS]} <- As ]
    of
        [VS] when is_integer(VS) -> {ok, VS};
        [] -> {error, novsn};
        _  -> {error, badarg}
    end.

%% @doc Get the developer provided version string of the module.
-spec version( atom() ) -> {ok, string()} | {error, term()}.
version( ModuleName ) when is_atom( ModuleName ) -> 
    MI = erlang:apply( ModuleName, module_info, [] ),
    case 
        catch [ VS || {compile, Cs} <- MI, {version, VS} <- Cs ]
    of
        [VS] when is_list(VS) -> {ok, VS};
        [] -> {error, noversion};
        _  -> {error, badarg}
    end.

%% @doc Get the list of exports for a provided module.
-spec exports( atom() ) -> {ok, [mfa()]} | {error, term()}.
exports( ModuleName ) when is_atom( ModuleName )  ->  
    case 
        erlang:apply( ModuleName, module_info, [ exports ] )
    of
        Es when is_list( Es ) -> {ok, Es};
        _                     -> {error, badarg}
    end.

%% ===========================================================================
%% Code Accessor Functionality
%% ===========================================================================

%% @doc Get the Raw Erlang code from a loaded BEAM module. This is useful if
%%   you want to do RegEx replacements before a `rewrite/2`, e.g. replace all
%%   calls to `modulev1` to `modulev2`.
%% @end
-spec get_code( mfa() | term() ) -> {ok, string()} | {error, term()}. 
get_code( Term ) -> 
    case get_ast( Term ) of
        {ok, AST} -> libhotswap_util:ast_to_code( AST );
        Error     -> Error
    end.        

%% @doc Get the Abstract Syntax Tree from a loaded BEAM module. This is useful
%%   if you want to do more advanced analysis before a `rewrite/2`, e.g. 
%%   reordering case statements.
%% @end
-spec get_ast( mfa() | term() ) -> {ok, ast()} | {error, term()}.
get_ast( {Module, _, _} = MFA ) -> ok;
    case libhotswap_util:get_beam( Module ) of
        {ok, BEAM} ->
            (case libhotswap_util:beam_to_ast( BEAM ) of
                 {ok, AST} -> libhotswap_util:ast_by_mfa( AST, MFA );
                 Error     -> Error
             end);
         Error -> Error
    end; 
get_ast( Erl ) -> libhotswap_util:term_to_ast( Erl ).


%% ===========================================================================
%% Module Manipulation
%% ===========================================================================

-spec add_export( mfa(), func() ) -> {ok, vsn()} | {error, term()}. 
add_export( MFA, Func ) -> ok.

-spec remove_export( mfa() ) -> {ok, vsn()} | {error, term()}.
remove_export( MFA ) -> ok.

-spec rewrite( mfa(), func() ) -> {ok, vsn()} | {error, term()}.
rewrite( MFA, Func ) -> ok.


%% ===========================================================================
%% Specialized functionality
%% ===========================================================================

-spec inject_in_function( mfa(), func(), pattern() ) -> {ok, vsn()} | {error, term()}.
inject_in_function( MFA, Func, Pattern ) -> ok.

-spec add_new_clause( mfa(), func(), non_neg_integer() ) -> {ok, vsn()} | {error, term()}.
add_new_clause( MFA, Func, Order ) -> ok.
