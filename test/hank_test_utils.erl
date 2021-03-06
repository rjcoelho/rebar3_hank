-module(hank_test_utils).

-export([init_per_testcase/2, end_per_testcase/1]).
-export([init/0, mock_context/1, analyze_and_sort/2, analyze_and_sort/3, set_cwd/1,
         abs_test_path/1]).

init_per_testcase(Config, TestDirName) ->
    {ok, Cwd} = file:get_cwd(), % Keep the original cwd
    set_cwd(TestDirName),
    [{cwd, Cwd} | Config].

end_per_testcase(Config) ->
    {value, {cwd, Cwd}, NewConfig} = lists:keytake(cwd, 1, Config),
    ok = file:set_cwd(Cwd),
    NewConfig.

%% @doc Initialize rebar3 to simulate running `rebar3 hank`
init() ->
    {ok, State} =
        rebar3_hank:init(
            rebar_state:new()),
    State.

mock_context(Apps) ->
    AppsAbs = maps:map(fun(_App, Path) -> filename:absname(Path) end, Apps),
    hank_context:new(AppsAbs).

analyze_and_sort(Files, Rules) ->
    analyze_and_sort(Files, Rules, mock_context(#{})).

analyze_and_sort(Files, Rules, Context) when is_map(Context) ->
    analyze_and_sort(Files, [], Rules, Context);
analyze_and_sort(Files, IgnoredFiles, Rules) ->
    analyze_and_sort(Files, IgnoredFiles, Rules, mock_context(#{})).

analyze_and_sort(Files, IgnoredFiles, Rules, Context) ->
    Results = hank:analyze(Files, IgnoredFiles, Rules, Context),
    lists:sort(
        maps:get(results, Results)).

set_cwd(RelativePathOrFilename) ->
    ok = file:set_cwd(abs_test_path(RelativePathOrFilename)).

abs_test_path(FilePath) ->
    filename:join(
        code:priv_dir(rebar3_hank), "test_files/" ++ FilePath).
