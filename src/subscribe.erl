%% @author Admin
%% @doc @todo Add description to subscribe.


-module(subscribe).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/2, connect/1]).


%% ====================================================================
%% Internal functions
%% ====================================================================

start_link(Fun, Args) ->
	spawn_link(?MODULE, Fun, Args).

connect(IP) -> 
   {ok, SocketSub} = chumak:socket(sub),
   chumak:subscribe(SocketSub, ""),
   case chumak:connect(SocketSub, tcp, IP, 5556) of
      {ok, _} ->
          %io:format("Binding OK with Pid: ~p ~p\n", [SocketSub, BindPid]), 
		  subscription(SocketSub);
      {error, ReasonSub} ->
          io:format("Subscription failed, reason: ~p\n", [ReasonSub]);
      _ ->
          io:format("Subscription failed\n")
   end.

% Получение уведомлений от сервера об изменениях базы разбивка данных на 3 части <<0>> - разделитель,
% отправка их на вывод на экран при помощи функции subhandling/3
subscription(SocketSub) ->
	case chumak:recv(SocketSub) of
	  {ok, Data} ->
       % io:format("Received ~ts\n", [unicode:characters_to_list(Data)]),
	    case binary:split(Data, <<0>>, [global]) of
	       [Tab, Event, Key] -> subhandling(Tab, Event, Key);
	        _ -> io:format("Error! Server attempt to send notification failed")
	    end;
	  {error, RecvReason} -> 
		    io:format("Error! Couldn't get notification from server, reason: ~p\n", [RecvReason]); 
	      _ -> io:format("Error! Couldn't get notification from server\n")
	end,  
    subscription(SocketSub).


% Вывод уведомлений от сервера на экран
subhandling(Tab, Event, Key) ->  
    case Event of
		<<48>> -> io:format("The Value of Key: ~w in table <~ts> was updated\n", [Key, unicode:characters_to_list(Tab)]);
        <<49>> -> io:format("The Key: ~w in table: <~ts> was deleted\n", [Key, unicode:characters_to_list(Tab)]);
	    _ -> io:format("Error! Server attempt to send notification failed")
    end.