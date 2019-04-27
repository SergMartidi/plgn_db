%% @author Admin
%% @doc @todo Add description to plgn_db1.


-module(plgn_db1).
-behaviour(application).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/2, stop/1, connect/1, disconnect/0, create_table/1, delete_table/1, update/3, update/4, delete/2, get/2]).



start(_StartType, _StartArgs) ->
               plgn_db1_sup:start_link().

%%--------------------------------------------------------------------


stop(_State) ->
	spawn(application, stop, [chumak]),
	ok.


connect(IP) -> 
   plgn_db1_sup:connect(IP).


disconnect() -> 
	plgn_db1_sup:disconnect().

	
create_table(Tab) ->
	plgn_db1_serv:command([check, [["0", Tab]]]).

delete_table(Tab) ->
	plgn_db1_serv:command([check, [["1", Tab]]]).

update(Tab, Key, Value) ->
	plgn_db1_serv:command([check, [["2", Tab, Key, Value, 0]]]).

update(Tab, Key, Value, Time) ->
	plgn_db1_serv:command([check, [["2", Tab, Key, Value, Time]]]).

delete(Tab, Key) ->
	plgn_db1_serv:command([check, [["3", Tab, Key]]]).

get(Tab, Key) -> 
	plgn_db1_serv:command([check, [["4", Tab, Key]]]).






