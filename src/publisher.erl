%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.
-module(publisher).
-export([main/0]).

main() ->
    application:start(chumak), chumak:start(1,1),
    {ok, Socket} = chumak:socket(pub),

    case chumak:bind(Socket, tcp, "localhost", 5556) of
        {ok, _BindPid} ->
            io:format("Binding OK with Pid: ~p\n", [Socket]);
        {error, Reason} ->
            io:format("Connection Failed for this reason: ~p\n", [Reason]);
        X ->
            io:format("Unhandled reply for bind ~p \n", [X])
    end,
    loop(Socket, 1).

loop(Socket, Pos) ->
	Message="Таблица"++binary_to_list(<<0>>)++integer_to_list(rand:uniform(2)-1)++binary_to_list(<<0>>)++integer_to_list(rand:uniform(100)),
    ok = chumak:send(Socket, unicode:characters_to_binary(Message)),
    io:format("~w ", [unicode:characters_to_binary(Message)]),
    timer:sleep(10000),
    loop(Socket, Pos + 1).
