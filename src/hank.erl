%%% @doc The Erlang Dead Code Cleaner
-module(hank).

-export([analyze/4]).

%% @doc Runs a list of rules over a list of files and returns all the
%%      dead code pieces it can find.
-spec analyze([file:filename()],
              [{file:filename(), hank_rule:t() | all}],
              [hank_rule:t()],
              hank_context:t()) ->
                 #{results => [hank_rule:result()], ignored => non_neg_integer()}.
analyze(Files, IgnoredFiles, Rules, Context) ->
    ASTs = [{File, get_ast(File)} || File <- Files],
    IgnoredRules =
        [{File, IgnoredRule}
         || {File, AST} <- ASTs,
            not lists:member({File, all}, IgnoredFiles),
            IgnoredRule <- ignored_rules(AST, Rules)]
        ++ [{File, Rule}
            || {File, IgnoredRule} <- IgnoredFiles,
               Rule <- Rules,
               IgnoredRule == all orelse IgnoredRule == Rule],
    AllResults =
        [Result#{rule => Rule}
         || Rule <- Rules, Result <- hank_rule:analyze(Rule, ASTs, Context)],
    {Results, Ignored} =
        lists:partition(fun(#{file := File, rule := Rule}) ->
                           not lists:member({File, Rule}, IgnoredRules)
                        end,
                        AllResults),
    #{results => Results, ignored => length(Ignored)}.

get_ast(File) ->
    case ktn_dodger:parse_file(File, [no_fail, parse_macro_definitions]) of
        {ok, AST} ->
            AST;
        {error, OpenError} ->
            erlang:error({cant_parse, File, OpenError})
    end.

ignored_rules(AST, Rules) ->
    FoldFun =
        fun(Node, Acc) ->
           case erl_syntax:type(Node) of
               attribute ->
                   try erl_syntax_lib:analyze_attribute(Node) of
                       {hank, {hank, ignore}} ->
                           Rules ++ Acc;
                       {hank, {hank, RulesToIgnore}} ->
                           RulesToIgnore ++ Acc;
                       _ ->
                           Acc
                   catch
                       _:_ ->
                           Acc
                   end;
               _ ->
                   Acc
           end
        end,
    erl_syntax_lib:fold(FoldFun, [], erl_syntax:form_list(AST)).
