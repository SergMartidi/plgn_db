%% @author Admin
%% @doc @todo Add description to client.


-module(client).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0]).



%% ====================================================================
%% Internal functions
%% ====================================================================


start() ->
	application:start(plgn_db1),
	IP=lists:droplast(io:get_line("Enter server IP address\n")),
    case plgn_db1:connect(IP) of
		{error, {invalid_ip, _}} -> start();
		{error, _} -> application:stop(plgn_db1), ok;
		    _  -> input()
	end.


input()-> 
	Command=string:tokens(lists:droplast(io:get_line("Enter command (<help> - help, <exit> - exit)\n")), " "),
	case Command of
		[] -> H="start", T="";
		_ -> [H|T]=Command
	end,
	case catch posnumber(lists:nth(4, T)) of
		{'EXIT',_} -> Time=true, Args=T;
		    false  -> Time=false, Args=T;
		    true   -> Time=true, Args=lists:sublist(T, 3)++[list_to_integer(lists:nth(4, T))]++lists:nthtail(4, T)
	end,
	case catch char_to_binary(lists:nth(2, Args)) of
		{'EXIT',_} -> Key=true, NewArgs=Args;
		    false  -> Key=false, NewArgs=Args;
		     Bin   -> Key=true, NewArgs=[hd(Args)|[Bin]]++lists:nthtail(2, Args)
	end,
	case catch char_to_binary(lists:nth(3, NewArgs)) of
		{'EXIT',_} -> Value=true, NewArgs2=NewArgs;
		    false  -> Value=false, NewArgs2=NewArgs;
		     Bin2   -> Value=true, NewArgs2=lists:sublist(NewArgs, 2)++[Bin2]++lists:nthtail(3, NewArgs)
	end,
	case H of
		"start" -> io:format("Bad command name or bad number of arguments\n"), input();
		"stop" -> io:format("Bad command name or bad number of arguments\n"), input();
		"connect" -> io:format("Bad command name or bad number of arguments\n"), input();
		"disconnect" -> plgn_db1:disconnect(), start();
		"exit" -> application:stop(plgn_db1);
		"help" -> io:format("help                                get help\n
exit                                close application\n
disconnect                          disconnect from server\n
create_table <table>                create table with name <table>\n
delete_table <table>                delete table with name <table>\n
update <table> <key> <value>        update value of <key> in <table> with new <value>\n
delete <table> <key>                delete <key> in <table>\n
get <table> <key>                   get value of <key> in <table>\n
<key> and <value> are binary data and must be entered in format <<byte:bit, byte2:bit,....>>, like this: <<56, \"hello\", 254:16, \"world\":32,......>>\n\n"),
				  input();
		 _  when Key==false andalso (H=="update" orelse H=="delete" orelse H=="get") ->
			      io:format("Error! Key name must be a binary data with size not more than 64 bytes\n"), input();
		 _  when Value==false andalso H=="update" ->
			      io:format("Error! Value must be a binary data with size not more than 1 Kbyte\n"), input();
		 _  when Time==false andalso H=="update" -> 
			     io:format("Error! Element lifetime must be a positive number with size not more than 64 bytes\n"), input();
		 _  when Time==false -> io:format("Bad command name or bad number of arguments\n"), input();
		 _ -> 
            case catch apply(plgn_db1, list_to_atom(H), NewArgs2) of
                {'EXIT',{undef, _}} -> io:format("Bad command name or bad number of arguments\n"), input();
				              _  -> input()
			end
    end.


char_to_binary(S) ->	
    case hd(S) == 60 andalso lists:nth(2,S) == 60 andalso lists:nth(length(S), S) == 62 
		                                         andalso lists:nth(length(S)-1, S) == 62 of
      true -> check_binary(string:tokens(lists:sublist(S, 3, length(S)-4), ","), <<>>);
      false -> false
	end.
	
check_binary(_, false) -> false; 
check_binary([], Acc) -> Acc;
check_binary([H|T], Acc) ->
case hd(H)==34 andalso lists:last(H)==34 of	
  true -> NewAcc=check_binary2(H, 8, Acc), check_binary(T, NewAcc);
  false ->   
	case string:split(H, ":", trailing) of
		[_, []] -> false;
		[[], _] -> false;
		[Byte, Bit]->
			case posnumber(Bit) andalso list_to_integer(Bit)>=8 andalso list_to_integer(Bit) rem 8 == 0 of
				true -> NewAcc=check_binary2(Byte, list_to_integer(Bit), Acc), check_binary(T, NewAcc);
				 _ -> false
			end;
		[H] ->  NewAcc=check_binary2(H, 8, Acc), check_binary(T, NewAcc);
	     _  -> false
	end
end.
					
check_binary2(Byte, Bit, Acc) ->	
	case hd(Byte)==34 andalso lists:last(Byte)==34 andalso length(Byte)/=1 of
       true -> S=tl(lists:droplast(Byte)), Bin= << <<X:Bit>> || X <- S >>, <<Acc/binary, Bin/binary>>;
       false -> 
         case posnumber(Byte) of
            true -> Int = list_to_integer(Byte), <<Acc/binary, Int:Bit>>;
			false -> false
		 end
	end.

posnumber([]) -> true;
posnumber([H|T]) when H>=48, H=<57 -> posnumber(T);
posnumber(_) -> false.



