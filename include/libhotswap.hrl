-type ast()  :: erl_parse:erl_parse().
-type vsn()  :: pos_integer().
-type func() :: string() | fun() | pfunc().
-type pfunc()   :: {'fun',1,_} | {'function',_,_,_,_}.
-type pattern() :: { non_neg_integer() | 'end', all | [ non_neg_integer() ] }.

