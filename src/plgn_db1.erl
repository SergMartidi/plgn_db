%% @author Admin
%% @doc @todo Add description to plgn_db1.


-module(plgn_db1).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1, stop/0, create_table/1, delete_table/1, update/3, update/4, delete/2, get/2]).




start(IP) -> 
   plgn_db1_sup:start_link(main, [start, [IP]]).


stop() -> 
	main:stop().

	
create_table(Tab) ->
	plgn_db1_sup:start_link(main, [check, [["0", Tab]]]).

delete_table(Tab) ->
	plgn_db1_sup:start_link(main, [check, [["1", Tab]]]).

update(Tab, Key, Value) ->
	plgn_db1_sup:start_link(main, [check, [["2", Tab, Key, Value, <<1>>]]]).

update(Tab, Key, Value, Time) ->
	plgn_db1_sup:start_link(main, [check, [["2", Tab, Key, Value, Time]]]).

delete(Tab, Key) ->
	plgn_db1_sup:start_link(main, [check, [["3", Tab, Key]]]).

get(Tab, Key) ->
	plgn_db1_sup:start_link(main, [check, [["4", Tab, Key]]]).






