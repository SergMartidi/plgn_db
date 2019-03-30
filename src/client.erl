%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.
-module(client).
-export([main/0, start/0]).


% У используемой мною библиотеки ZeroMQ Chumak есть недостаток.
% Там нету вынесенных для использования функций для разрыва соединения.
% То есть, если ничего не делать, то даже после выхода из программы там остается 
% висеть процесс, который пытается соединиться с сервером. Поэтому приходится
% убивать его через exit(_,kill).В этом случае судя по всему обрушивается вся библиотека
% и выскакивает ошибка, и вот чтобы это хотя бы выглядело красиво и сообщение об ошибке не выходило
% в терминал я сделал функцию main  и запустил отсюда уже основную функцию start/0 в параллельном потоке. 
% К сожалению как по нормальному завершать соединение я выяснить не смог. Также хочу отметить особенность
% взаимодействие клиент-сервер. На каждый отправленный фрейм клиентом идет получение ответа от сервера.
% Сервер не принимает несколько фреймов подряд без ответа. Не уверен правильно это или нет. Но никак 
% было не заставить tuj получать несколько фреймов подряд. Клиент в принципе может слать несколько
% фреймов подряд, а вот сервер больше одного принимать не хочет.          


main() -> process_flag(trap_exit, true),
	spawn_link (fun() -> start() end), 
	receive
		_ -> ok
	end.
   
		 

% В этой функции сначала идет получение IP от пользователя через функцию getip/0, далее идет 
% создание req порта, создание отдельного процесса для подключение к нему,
% После этого идет подключение к rep серверу и попытка отправить тестовое сообщение,
% в случае неудачи програма завершается, в случае успеха управление программой передается  
% в функцию subconnect/2
start() ->
    application:start(chumak), chumak:start(1,1),	
    IP=getip(), io:format("Соединение с сервером.....\n"),
	{_, Socket0} = chumak:socket(req, "my-req"),
    case is_tuple(Socket0) of
		true -> {_, Socket} = Socket0;
		false -> Socket=Socket0
    end,
	 case chumak:connect(Socket, tcp, IP, 5555) of
        {ok, Pid} ->
		%	io:format("Binding OK with Pid: ~p ~p\n", [Socket, Pid]),
            Flagreq = send_message(Socket, "7", "7", "7", 1);
        {error, Reason} ->
            io:format("Не удалось соединиться с сервером, причина: ~p\n", [Reason]), Flagreq=false;
        _ ->
            io:format("Ошибка коммуникации с сервером\n"), Flagreq=false
    end,
	case Flagreq of
		true -> io:format("Соединение с сервером установлено \n"), subconnect(Socket, IP);
		  _  -> io:format("Программа завершена\n"), application:stop(chumak)
	end.
% В этой функции сначала идет создание sub порта, создание отдельного процесса для подключение к нему,
% открывается параллельный поток и в нем осуществляется соединение с Pub сервером и получение от него уведомлений
% В случае неудачи основная часть программы продолжит работу с выводом сообщения об ошибке и о том, что 
% уведомления об изменении базы присылаться не будут.(для этого я подкорректировал файл chumak_peer.erl 
% в исходниках) Все то время, что программа будет работать, будут производиться попытки соединения 
% с pub сервером. И в любом случае независимо от доступности pub сервера управление программой передается в 
% функцию input/2. 
subconnect(Socket, IP) -> 
   {ok, SocketSub} = chumak:socket(sub),
   chumak:subscribe(SocketSub, ""),
   case chumak:connect(SocketSub, tcp, IP, 5556) of
      {ok, BindPid} ->
    %      io:format("Binding OK with Pid: ~p ~p\n", [SocketSub, BindPid]), 
		  spawn(fun() -> subscription(SocketSub) end);
      {error, ReasonSub} ->
          io:format("Не удалось соединиться с сервером уведомлений, причина: ~p\n", [ReasonSub]);
      _ ->
          io:format("Ошибка коммуникации с сервером уведомлений\n")
   end,
   input(Socket, SocketSub).	

% Получение IP сервера от пользователя с проверкой на допустимые значения
getip() ->     
    IP=lists:droplast(io:get_line("Введите IP адрес сервера\n")),
	case ipcheck(IP,[], 0) of
		true -> IP;
		false -> io:format("Ошибка! Введено недопустимое значение IP\n"), getip()
	end.

% Проверка IP на допустимые значения
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
				   

% Здесь идет получение команды и аргументов от пользователя и далее идет проверка на валидность 
% первого слова, которое является командой и проверка на верное количество аргументов в зависимости от команды
% Для получения первого слова используется функция word/2, для получения количества слов в строке используется
% функция wordsnumber/1. В случае неудачи выдается сообшение об ошибке ввода и программа предлагает заново
% ввести команду. В случае успеха управление программой передается в функцию lncheck/6. При этом в качестве
% одного из аргументов передается число от 0 до 4 в строковом виде, которое зависит от того какую команду
% использовал пользователь, таким образом осуществляется перевод команды в число от 0 до 4 для будущей пересылки
% Также я сделал команду exit для выхода из программы
input(Socket, SocketSub)->
	Command=lists:droplast(io:get_line("Введите команду\n")),
	Operator = word(1, Command), Wordsnumber = wordsnumber(Command),
    if  
		Operator=="create_table" andalso Wordsnumber==2 -> lncheck(Socket, SocketSub, Command,  "0", 2, 2);
		Operator=="create_table"  -> io:format("Ошибка! Команда create_table должна иметь 1 аргумент\n"), input(Socket, SocketSub);
		Operator=="delete_table" andalso Wordsnumber==2 -> lncheck(Socket, SocketSub, Command, "1", 2, 2);
		Operator=="delete_table" -> io:format("Ошибка! Команда delete_table должна иметь 1 аргумент\n"), input(Socket, SocketSub);
        Operator=="update" andalso Wordsnumber==4 -> lncheck(Socket, SocketSub, Command, "2", 4, 2);
        Operator=="update" andalso Wordsnumber==5 -> lncheck(Socket, SocketSub, Command, "2", 5, 2);
        Operator=="update" -> io:format("Ошибка! Команда update должна иметь 3 или 4 аргументов\n"), input(Socket, SocketSub);
		Operator=="delete" andalso Wordsnumber==3 -> lncheck(Socket, SocketSub, Command, "3", 3, 2);
        Operator=="delete" -> io:format("Ошибка! Команда delete должна иметь 2 аргумента\n"), input(Socket, SocketSub);
		Operator=="get" andalso Wordsnumber==3 -> lncheck(Socket, SocketSub, Command, "4", 3, 2);
		Operator=="get" -> io:format("Ошибка! Команда get должна иметь 2 аргумента\n"), input(Socket, SocketSub);
		Operator=="exit" ->  io:format("Программа завершена\n"), chumak:cancel(SocketSub, ""), application:stop(chumak), exit(SocketSub, kill);
		true -> io:format("Ошибка! Неверно введена команда\n"), input(Socket, SocketSub)
	end.


% В этой функции осуществляется проверка длины аргументов в байтах, чтобы они соотвествовали условию задачи.
% а также для команды update проверка  четвертого аргумента(если он есть) на то чтобы это было число 
% при помощи функции posnumber/1.
% Входные параметры: Opr - число от 0 до 4, означающее команду, Wordsnumber - количество слов в строке,
% полученной от пользователя. Здесь также используется функция word/2, которая возвращает слово из строки,
% по его порядковому номеру. В случае неудачи выводится сообщение об ошибке и управление передается
% в функцию input/2, где пользователю снова предлагается ввести команду. 
% В случае успеха  мы переходим в функцию send/6 
lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 2) when Wordsnumber>=2 -> 
	case byte_size(unicode:characters_to_binary(word(2, Command)))=<254 of
		  true -> lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 3);
		  false ->io:format("Ошибка! Размер имени таблицы должен быть не более 255 байт\n"), input(Socket, SocketSub)  
	end;
lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 3) when Wordsnumber>=3 -> 
	case byte_size(unicode:characters_to_binary(word(3, Command)))=<64 of
		  true -> lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 4);
		  false ->io:format("Ошибка! Размер ключа должен быть не более 64 байт\n"), input(Socket, SocketSub)  
	end;
lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 4) when Wordsnumber>=4 -> 
	case byte_size(unicode:characters_to_binary(word(4, Command)))=<1024 of
		  true -> lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 5);
		  false ->io:format("Ошибка! Размер данных должен быть не более 1 Кбайта\n"), input(Socket, SocketSub)  
	end;
lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 5) when Wordsnumber>=5 -> 
	Word5 = word(5, Command),
	case length(Word5)=<64 andalso posnumber(Word5)==true of
		  true  -> lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, 6);
		  false -> io:format("Ошибка! Время жизни элемента должно быть целым беззнаковым числом длиной не более 64 символов\n"), input(Socket, SocketSub)  
	end;
lncheck(Socket, SocketSub, Command, Opr, Wordsnumber, _) -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 1).


% Возвращает слово из строки по его порядковому номеру
word(N, L) -> word(N, L, [], 1, 32).

word(N, [], Acc, N, _) -> Acc;
word(N, [32|T], _, I, 32) -> word(N, T, [], I, 32); 
word(N, [32|_], Acc, N, _) -> Acc;
word(N, [32|T], _, I, _) -> word(N, T, [], I+1, 32); 
word(N, [H|T], Acc, N, _) -> word(N, T, Acc++[H], N, H); 
word(N, [H|T], Acc, I, _) -> word(N, T, Acc, I, H).

% Возвращает количестов слов в строке 
wordsnumber([]) -> 0;
wordsnumber(L) -> wordsnumber(L,0,32).

wordsnumber([], N, 32) -> N;
wordsnumber([], N, _) -> N+1;
wordsnumber([32|T], N, 32)  -> wordsnumber(T, N, 32);
wordsnumber([32|T], N, _)  -> wordsnumber(T, N+1, 32);
wordsnumber([H|T], N, _) -> wordsnumber(T, N, H).

% Возвращает true если строка является числом
posnumber([]) -> true;
posnumber([H|T]) when H>=48, H=<57 -> posnumber(T);
posnumber(_) -> false.
	

% Функция отправляет по очереди слова из полученной от пользователя строки в функцию send_message/5
% для отправки их на сервер фреймами. вместо первого слова, которое является командой, отправляется 
% соответствующее число. В случае команды update только с 3мя аргументами, четвертым аргументом шлется "a".
% Закончив, передает упаравление программой в функцию ввода команды input/2. 
% После каждого фрейма обязательно нужно получить ответ от сервера.
% Несколько подряд фреймов сервер не принимает. 
send(Socket, SocketSub, Command, Opr, Wordsnumber, 1) ->
	     case send_message(Socket, Command, Opr, Opr, 1) of
			 true -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 2);
			 false -> input(Socket, SocketSub)
		 end;
send(Socket, SocketSub, Command, Opr, Wordsnumber, 2) -> 
	     case send_message(Socket, Command, word(2, Command), Opr, 2) of
			 true -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 3);
			 false -> input(Socket, SocketSub)
		 end;
send(Socket, SocketSub, Command, Opr, Wordsnumber, 3) when Wordsnumber>=3-> 
	      case send_message(Socket, Command, word(3, Command), Opr, 3) of
			  true -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 4);
			  false -> input(Socket, SocketSub)
		  end;
send(Socket, SocketSub, Command, Opr, Wordsnumber, 4) when Wordsnumber>=4-> 
	      case send_message(Socket, Command, word(4, Command), Opr, 4) of
			  true -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 5);
			  false -> input(Socket, SocketSub)
		  end;
send(Socket, SocketSub, Command, Opr, Wordsnumber, 5) when Wordsnumber>=5-> 
	      case send_message(Socket, Command, word(5, Command), Opr, 5) of
			  true -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 6);
			  false -> input(Socket, SocketSub)
		  end;
send(Socket, SocketSub, Command, Opr, Wordsnumber, 5) -> 
	      case send_message(Socket, Command, "a", Opr, 5) of
			  true -> send(Socket, SocketSub, Command, Opr, Wordsnumber, 6);
			  false -> input(Socket, SocketSub)
		  end;
send(Socket, SocketSub, _, _, _, _) -> input(Socket, SocketSub).


% Эта функция переводит полученную строку в бинарные даные добавляет <<0>>(требования сервера) 
% и посылает на сервер. 
send_message(Socket, Command, Message, Opr, N) ->
    case chumak:send(Socket, unicode:characters_to_binary(Message++binary_to_list(<<0>>))) of
        ok ->
            send_message2(Socket, Command, Opr, N);
        {error, Reason} ->
            io:format("Ошибка! Не удалось отправить информацию на сервер, причина: ~p\n", [Reason]),
			false
    end.

% Данная функция получает ответ от сервера и отправляет его дальше в функцию recvhandling/5 для обработки 
send_message2(Socket, Command, Opr, N) ->
    case chumak:recv(Socket) of
        {ok, RecvMessageBin} ->
			RecvMessage = unicode:characters_to_list(RecvMessageBin),
		   % io:format("~p\n", [RecvMessage]),
			recvhandling(Socket, Command, RecvMessage, Opr, N), true;
        {error, RecvReason} ->
            io:format("Ошибка! Не удалось получить ответ от сервера, причина: ~p\n", [RecvReason]),
			false
    end.

% Напоминаю, что после каждого отправленного фрейма программа получает ответ от сервера.
% Фунцкия обрабатывает ответ от сервера, в случае если сообщение еще не полностью было отправлено на сервер
% (не все фреймы ушли) она ничего не делает(функция  send/6 продолжает свою работу).
% В случае если собшение полностью передано(это определяется по команде, каждая команда имеет 
% фиксированное количество аргументов, а значит фреймов) проверяется ответ, если это "ок" то для команд
% 0, 1 и 2 напрямую идет вызов функцию вывода ответа на экран printanswer/3, тк второй фрейм не нужен
% Для всех остальных случаев сначала вызывается функция receive_message/2 которая получает второй фрейм
% ответа и уже вместе с результатом этой функции вызывается функция printanswer/3
recvhandling(_, Command, "ok", "0", 2) -> printanswer("ok", Command, "0");
recvhandling(Socket, Command, RecvMessage, "0", 2) -> printanswer(receive_message(Socket, RecvMessage), Command, "0");
recvhandling(_, Command, "ok", "1", 2) -> printanswer("ok", Command, "1");
recvhandling(Socket, Command, RecvMessage, "1", 2) -> printanswer(receive_message(Socket, RecvMessage), Command, "1");
recvhandling(_, Command, "ok", "2", 5) -> printanswer("ok", Command, "2");
recvhandling(Socket, Command, RecvMessage, "2", 5) -> printanswer(receive_message(Socket, RecvMessage), Command, "2");
recvhandling(Socket, Command, RecvMessage, "3", 3) -> printanswer(receive_message(Socket, RecvMessage), Command, "3");
recvhandling(Socket, Command, RecvMessage, "4", 3) -> printanswer(receive_message(Socket, RecvMessage), Command, "4");
recvhandling(_, _, _, _, _) -> true.


% Делает запрос на получение второго фрейма ответа от сервера
receive_message(Socket, FirstMessage) -> 
	 case chumak:send(Socket, <<54, 0>>) of
        ok ->
            receive_message2(Socket, FirstMessage);
        {error, Reason} ->
            io:format("Ошибка! Не удалось отправить информацию на сервер, причина: ~p\n", [Reason]),
			false
     end.

% Получает второй фрейм ответа от сервера
receive_message2(Socket, FirstMessage) -> 
     case chumak:recv(Socket) of
        {ok, RecvMessage} ->
		 %   io:format("~p\n", [unicode:characters_to_list(RecvMessage)]),
			{FirstMessage, RecvMessage};
        {error, RecvReason} ->
            io:format("Ошибка! Не удалось получить ответ от сервера, причина: ~p\n", [RecvReason]),
			false
     end.


% Выводит ответ от сервера на экран
printanswer(false, _, _) -> false;
printanswer("ok", Command, "0") -> 
     io:format("Таблица с именем <~ts> успешно создана\n", [word(2, Command)]);
printanswer({"error", Data}, Command, "0") -> 
	 io:format("Ошибка! Не удалось создать таблицу с именем <~ts>, причина: <~ts>\n", [word(2, Command), unicode:characters_to_list(Data)]);
printanswer("ok", Command, "1") -> 
     io:format("Таблица с именем <~ts> успешно удалена\n", [word(2, Command)]);
printanswer({"error", Data}, Command, "1") -> 
	 io:format("Ошибка! Не удалось удалить таблицу с именем <~ts>, причина: <~ts>\n", [word(2, Command), unicode:characters_to_list(Data)]);
printanswer("ok", Command, "2") -> 
     io:format("Ключ: ~w в таблице: <~ts> успешно обновлен, новое значение: ~w\n", [unicode:characters_to_binary(word(3, Command)), word(2, Command), unicode:characters_to_binary(word(4, Command))]);
printanswer({"error", Data}, Command, "2") -> 
	 io:format("Ошибка! Не удалось обновить значение ключа: ~w в таблице: <~ts>, причина: <~ts>\n", [unicode:characters_to_binary(word(3, Command)), word(2, Command), unicode:characters_to_list(Data)]);
printanswer({"ok", Data}, Command, "3") ->
	io:format("Ключ: ~w и его значение: ~w в таблице: <~ts> успешно удалены\n", [unicode:characters_to_binary(word(3, Command)), Data, word(2, Command)]);
printanswer({"error", Data}, Command, "3") ->
	io:format("Ошибка! Не удалось удалить ключ: ~w в таблице: <~ts>, причина: <~ts>\n", [unicode:characters_to_binary(word(3, Command)), word(2, Command), unicode:characters_to_list(Data)]);	
printanswer({"ok", Data}, Command, "4") ->
	io:format("Ключу: ~w в таблице: <~ts> соответствует значение: ~w\n", [unicode:characters_to_binary(word(3, Command)), word(2, Command), Data]);
printanswer({"error", Data}, Command, "4") ->
	io:format("Ошибка! Не удалось получить значение ключа: ~w в таблице: <~ts>, причина: <~ts>\n", [unicode:characters_to_binary(word(3, Command)), word(2, Command), unicode:characters_to_list(Data)]);	
printanswer(_, _, _) -> io:format("Ошибка коммуникации с сервером!\n").


% В случае если пробел разделитель.
%subscription(SocketSub) ->
%	{ok, Data} = chumak:recv(SocketSub),
 %   io:format("Received ~p\n", [unicode:characters_to_list(Data)]),
%	subhandling(Data),
%    subscription(SocketSub).
%subhandling(Data) ->  
%    Message = binary_to_list(Data),
%    case word(2, Message) of
%		"0" -> io:format("Значение ключа: <~ts> в таблице <~ts> обновлено\n", [word(3, Message), word(1, Message)]);
%        "1" -> io:format("Ключ: <~ts> в таблице: <~ts> был удален\n", [word(3, Message), word(1, Message)]);
%	    _ -> true
%    end.


% Получение уведомлений от сервера об изменениях базы разбивка данных на 3 части <<0>> - разделитель,
% отправка их на вывод на экран при помощи функции subhandling/3
subscription(SocketSub) ->
	case chumak:recv(SocketSub) of
	  {ok, Data} ->
       % io:format("Received ~ts\n", [unicode:characters_to_list(Data)]),
	    case binary:split(Data, <<0>>, [global]) of
	       [Tab, Event, Key] -> subhandling(Tab, Event, Key);
	        _ -> io:format("Ошибка! Попытка сервера отправить уведомление об изменении базы закончилась неудачей")
	    end;
	  {error, RecvReason} -> 
		    io:format("Ошибка! Не удалось получить уведомление от сервера, причина: ~p\n", [RecvReason]); 
	      _ -> io:format("Ошибка! Не удалось получить уведомление от сервера\n")
	end,  
    subscription(SocketSub).


% Вывод уведомлений от сервера на экран
subhandling(Tab, Event, Key) ->  
    case Event of
		<<48>> -> io:format("Значение ключа: ~w в таблице <~ts> обновлено\n", [Key, unicode:characters_to_list(Tab)]);
        <<49>> -> io:format("Ключ: ~w в таблице: <~ts> был удален\n", [Key, unicode:characters_to_list(Tab)]);
	    _ -> io:format("Ошибка! Попытка сервера отправить уведомление об изменении базы закончилась неудачей")
    end.


