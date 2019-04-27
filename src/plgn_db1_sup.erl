%%%-------------------------------------------------------------------
%% @doc plgn_db1 top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(plgn_db1_sup).

-behaviour(supervisor).


%% API
-export([start_link/0, init/1, connect/1, disconnect/0]).





%%====================================================================
%% API functions
%%====================================================================


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE , []).

init([]) -> 
	{ok, {{one_for_one, 3, 10}, []}}.


connect(IP) -> 
	supervisor:start_child(plgn_db1_sup, #{id=>serv, start=>{plgn_db1_serv, start_link, [IP]}, restart=>permanent, shutdown=>3000}).

disconnect() -> 
	supervisor:terminate_child(plgn_db1_sup, serv),
	supervisor:delete_child(plgn_db1_sup, serv),
	timer:sleep(500),
    application:stop(chumak),
	io:format("Successfully disconnected\n"),
	{ok, disconnected}.
%%====================================================================
%% Internal functions
%%====================================================================





