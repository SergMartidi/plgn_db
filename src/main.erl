%% @author Admin
%% @doc @todo Add description to main.


-module(main).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/2, init/2, start/1, stop/0, check/1, ipcheck/1]).




%% ====================================================================
%% Internal functions
%% ====================================================================
start_link(Fun, Args) -> 
	spawn_link(?MODULE, init, [Fun, Args]).

init(Fun, Args) ->
	apply(?MODULE, Fun, Args).
	


start(IP) ->
case application:start(chumak) of
  ok ->
    io:format("Connecting to server.....\n"),
	{_, Socket0} = chumak:socket(req, "my-req"),
    case is_tuple(Socket0) of
		true -> {_, Socket} = Socket0;
		false -> Socket=Socket0
    end,
	case chumak:connect(Socket, tcp, IP, 5555) of
        {ok, _} ->
			%io:format("Binding OK with Pid: ~p ~p\n", [Socket, Pid]),
            Flagreq = send_message(Socket, "7", "7", "7");
        {error, Reason} ->
            io:format("Couldn't connect to server, reason: ~p\n", [Reason]), Flagreq=false;
        _ ->
            io:format("Server error communication\n"), Flagreq=false
    end,
	case Flagreq of
		true -> io:format("Connection established\n"),  catch shell ! {start, ok}, 
				plgn_db1_sup:start_link(subscribe, [connect, [IP, Socket]]);
		  _  -> catch shell ! {start, {error, connection_failed}}
	end;
  _ -> catch shell ! {start, ok} 
end.


stop() -> 
	spawn(application, stop, [chumak]),
	plgn_db1_sup:msg_clear(),
	catch unregister(shell),
	process_flag(trap_exit, true),
    catch subsup ! shutdown,
	io:format("Application finished\n"),
	{ok, app_closed}.


check(Command=[_|T]) -> check(Command, T, 2).

check(Command, [], _) -> 
	Ref=make_ref(),
	catch subsup ! {self(), Ref, socket},
	receive
		{Ref, Socket} -> send(Socket, Command, Command, 1)
	end;
check(Command, [H|T], 2) ->  
	case  is_list(H) andalso byte_size(unicode:characters_to_binary(H))=<254 andalso stringcheck(H) of
		  true -> check(Command, T, 3);
		  false ->io:format("Error! Table name must be string with size not more than 255 bytes\n"), catch shell ! {result, {error, invalid_table}}  
	end;         
check(Command, [H|T], 3) ->  
	case  is_binary(H) andalso byte_size(H)=<64 of
		  true -> check(Command, T, 4);
		  false ->io:format("Error! Key name must be a binary data with size not more than 64 bytes\n"), catch shell ! {result, {error, invalid_key}}  
	end;    
check(Command, [H|T], 4) ->  
	case  is_binary(H) andalso byte_size(H)=<1024 of
		  true -> check(Command, T, 5);
		  false ->io:format("Error! Value must be a binary data with size not more than 1 Kbyte\n"), catch shell ! {result, {error, invalid_value}}  
	end;    
check(Command, [H|T], 5) ->  
	case  is_integer(H) andalso H>0 andalso byte_size(integer_to_binary(H))=<64 orelse H==<<1>> of
		  true -> check(Command, T, 6);
		  false ->io:format("Error! Element lifetime must be a positive number with size not more than 64 bytes\n"), catch shell ! {result, {error, invalid_time}}  
	end. 



send(Socket, [H|T], Command, I) -> 
	case Result=send_message(Socket, H, Command, I) of
		true -> send(Socket, T, Command, I+1);
		false -> catch shell ! {result, {error, sending_failed}};
		 _  -> catch shell ! {result, Result}
	end.


send_message(Socket, Message, Command, I) ->
	if 
		is_list(Message) -> BinMsg=unicode:characters_to_binary(Message);
		is_integer(Message) -> BinMsg=integer_to_binary(Message);
         true -> BinMsg=Message
    end,
    case chumak:send(Socket, <<BinMsg/binary, 0>>) of
        ok ->
            send_message2(Socket, Command, I);
        {error, Reason} ->
            io:format("Error! Failed to send information to server, reason: ~p~nPossibly previous request hasn't been processed yet\n", [Reason]),
			false
    end.

send_message2(Socket, Command, I) ->
    case chumak:recv(Socket) of
        {ok, RecvMessageBin} ->
			RecvMessage = unicode:characters_to_list(RecvMessageBin),
		   % io:format("~p\n", [RecvMessage]),
			recvhandling(Socket, Command, RecvMessage, hd(Command), I);
        {error, RecvReason} ->
            io:format("Error! Couldn't receive answer from server, reason: ~p\n", [RecvReason]),
			false
    end.


recvhandling(_, Command, "ok", "0", 2) -> printanswer("ok", Command, "0");
recvhandling(Socket, Command, RecvMessage, "0", 2) -> printanswer(receive_message(Socket, RecvMessage), Command, "0");
recvhandling(_, Command, "ok", "1", 2) -> printanswer("ok", Command, "1");
recvhandling(Socket, Command, RecvMessage, "1", 2) -> printanswer(receive_message(Socket, RecvMessage), Command, "1");
recvhandling(_, Command, "ok", "2", 5) -> printanswer("ok", Command, "2");
recvhandling(Socket, Command, RecvMessage, "2", 5) -> printanswer(receive_message(Socket, RecvMessage), Command, "2");
recvhandling(Socket, Command, RecvMessage, "3", 3) -> printanswer(receive_message(Socket, RecvMessage), Command, "3");
recvhandling(Socket, Command, RecvMessage, "4", 3) -> printanswer(receive_message(Socket, RecvMessage), Command, "4");
recvhandling(_, _, _, _, _) -> catch shell ! {frame, sent}, true.


% Делает запрос на получение второго фрейма ответа от сервера
receive_message(Socket, FirstMessage) -> 
	 case chumak:send(Socket, <<54, 0>>) of
        ok ->
            receive_message2(Socket, FirstMessage);
        {error, Reason} ->
            io:format("Error! Couldn't send information to server, reason: ~p\n", [Reason]),
			false
     end.

% Получает второй фрейм ответа от сервера
receive_message2(Socket, FirstMessage) -> 
     case chumak:recv(Socket) of
        {ok, RecvMessage} ->
		 %   io:format("~p\n", [unicode:characters_to_list(RecvMessage)]),
			{FirstMessage, RecvMessage};
        {error, RecvReason} ->
            io:format("Error! Couldn't receive answer from server, reason: ~p\n", [RecvReason]),
			false
     end.


% Выводит ответ от сервера на экран
printanswer(false, _, _) -> false;
printanswer("ok", Command, "0") -> 
     io:format("Table with name <~ts> successfully created\n", [lists:nth(2, Command)]),
	 {ok};
printanswer({"error", Data}, Command, "0") -> 
	 io:format("Error! Couldn't create table with name <~ts>, reason: <~ts>\n", [lists:nth(2, Command), unicode:characters_to_list(Data)]),
     {error, unicode:characters_to_list(Data)};
printanswer("ok", Command, "1") -> 
     io:format("Table with name <~ts> successfully deleted\n", [lists:nth(2, Command)]),
	 {ok};
printanswer({"error", Data}, Command, "1") -> 
	 io:format("Error! Couldn't delete the table with name <~ts>, reason: <~ts>\n", [lists:nth(2, Command), unicode:characters_to_list(Data)]),
	 {error, unicode:characters_to_list(Data)};
printanswer("ok", Command, "2") -> 
     io:format("The Key: ~w in table: <~ts> successfully updated, new value: ~w\n", [lists:nth(3, Command), lists:nth(2, Command), lists:nth(4, Command)]),
	 {ok};
printanswer({"error", Data}, Command, "2") -> 
	 io:format("Error! Couldn't update value of the Key: ~w in table: <~ts>, reason: <~ts>\n", [lists:nth(3, Command), lists:nth(2, Command), unicode:characters_to_list(Data)]),
	{error, unicode:characters_to_list(Data)};
printanswer({"ok", Data}, Command, "3") ->
	io:format("The Key: ~w and it's value: ~w in table: <~ts> successfully deleted\n", [lists:nth(3, Command), Data, lists:nth(2, Command)]),
	{ok, Data};
printanswer({"error", Data}, Command, "3") ->
	io:format("Error! Couldn't delete the Key: ~w in table: <~ts>, reason: <~ts>\n", [lists:nth(3, Command), lists:nth(2, Command), unicode:characters_to_list(Data)]),
	{error, unicode:characters_to_list(Data)};	
printanswer({"ok", Data}, Command, "4") ->
	io:format("The Key: ~w in table: <~ts> correspondes to the value: ~w\n", [lists:nth(3, Command), lists:nth(2, Command), Data]),
	{ok, Data};
printanswer({"error", Data}, Command, "4") ->
	io:format("Error! Couldn't get value for the Key: ~w in table: <~ts>, reason: <~ts>\n", [lists:nth(3, Command), lists:nth(2, Command), unicode:characters_to_list(Data)]),
	{error, unicode:characters_to_list(Data)};	
printanswer(_, _, _) -> io:format("Communication error with the server!\n"), {error, communication}.


ipcheck(IP) -> ipcheck(IP, [], 0).
ipcheck([], [], _) -> false;
ipcheck([], L, 3) -> case  list_to_integer(L)>=0 andalso list_to_integer(L)=<255 of 
						 true -> true;
						 false -> false
					 end;
ipcheck([], _, _) -> false;
ipcheck([46|_], [], _)  -> false;
ipcheck([46|T], L, PN) -> case list_to_integer(L)>=0 andalso list_to_integer(L)=<255 of
							 true -> ipcheck(T, [], PN+1);
							 false -> false
						  end;
ipcheck([H|T], L, PN) when H>=48, H=<57 -> ipcheck(T, L++[H], PN);
ipcheck([_|_], _, _) -> false.	

stringcheck([]) -> true;
stringcheck([H|T]) when H>=32 andalso H=<126 orelse H>=1040 andalso H=<1103 orelse H==1105 orelse H==1025 -> stringcheck(T);
stringcheck(_) -> false.

