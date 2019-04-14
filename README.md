# plgn_db

Здесь пока представлен только клиент для этого задания.

Порты, используемые для работы: 5555 и 5556.

В модуле plgn_db1 вынесены функции API, с помощью которых можно взаимодействовать с сервером напрямую,

при запуске каждой API функции  помимо текстового сообщения возвращается результат, 

так что к API можно делать клиент, в том числе графический.

Все API фуекции можно посмотреть в файле plgn_db1.src

Также я прикрутил к API консольный клиент. 

Запуск клиента: client:start(). 

Также здесь есть 2 простеньких сервера для теста: REP и PUB.

Запускаются: rep_server:main()  и publisher:main().

rep_server на все запросы от клиента отвечает рандомно ok или error.

publisher каждые 10 секунд  шлет сообщение из 3х слов первое: <Таблица>(название таблицы) 2е: рандомно <0> или <1> (база обновлена или удалена) 

3е: рандомное число (означающе имя ключа).

Для теста клиента этого вроде бы достаточно.


                                                 Описание программы:
												 

В Модуле  plgn_db1 вынесены все API функции. В модуле main проходят все основные рассчеты. В модуле plgn_db1_sup реализованы наблюдатели,

необходимые для работы программы. Реализация пока что без использования OTP (supervisor, gen_server).

При помощи команды plgn_db1:start(<IP>) запускается процесс подключения клиента к серверу. 

Для этого запускается наблюдатель startsup, в нем проверяется корректность введенного IP и в случае успеха создается процесс,

в котором запускается функция main:start/1.

Там запускается библиотека chumak, создается процесс для REQ порта и процесс для подключения к этому порту, далее шлется тестовое сообщение серверу,

в случае неудачи, после определенного количества попыток, наблюдателю посылается сообщение об этом, наблюдатель завершает работу программы.

В случае успеха наблюдателю приходит сообщение об этом, он завершает свою работу. А прямо из модуля main идет запуск  нового наблюдателя subsup,

в качестве аргументов ему передаются IP адрес сервера и номер процесса порта REQ. Этот наблюдатель запускает в отдельном процессе подписку

на уведомления от сервера. В случае неудачи при подключении к серверу PUB выдается сообщение о том что подписка недоступна, 

а попытки подключения будут происходить все то время что работает программа. На работу самой программы это не сказывается. В случае падения процесса,

отвечающего за подписку процесс будет перезапускаться. А модуль sub помимо наблюдения за подпиской еще выполняет роль хранителя номера

процесса порта REQ, который необходим для дальнейшего взаимодействия с сервером REP, и в дальнейшем по запросу эта информация будет 

предоставляться другим процессам. Этот наблюдатель висит все то время что работает программа.

Запуск команд. При запуске команд происходит запуск наблюдателя commsup, который в свою очередь спаунит процесс и запускает в нем функцию 

main:check/1, в качстве аргумента ей передается список, в котором содержится команда и аргументы этой команды. В этой функции производятся

все проверки на допустимые значения аргументов, включая проверки на их тип и на допустимый размер в байтах.  Если все ок, запрашивается номер 

процесса порта REQ у наблюдателя subsup, и далее список вместе с портом пересылается в функцию send/4. Дале происходит пофреймовая пересылка 

списка с командой и аргументами. Сам же наблюдатель commsup отводит 3 секунды на пресылку каждого фрейма, в случае истечения этого времени

(это означает что сервер не доступен) и в том случае, если еще не было послано ни одного фрейма, сообщает об ошибке и прекращает свою работу. 

Программа же будет пытаться завершить пересылку.
 
 Это связано с механизмом работы библиотки chumak, который в случае неудачи в любом случае пытается переслать фрейм, отменить это невозможно.
 
 В этом случае лучше переслать и все оставшиеся фреймы, чтобы у сервера не было проблем  с обработкой незавершенного сообщения.

В случае же поступления еще одной команды от юзера при незавершенной предыдущей будет выдаваться сообщение об ошибке и о том что возможно

предыдущая команда еще не завершена.  Эта команда никуда не пересылается. Еще возможен случай, когда сервер перестает быть доступен в середине 

послания собщения, то есть когда несколько фреймов уже отправлены и еще несколько ждут отправки. В этом случае программа завершается. 

Иначе могут быть проблемы с сервером, который в качестве первого фрейма получит мой 3-й или 4-й.  Таким образом программа более менее защищена 

от неожиданностей со стороны сервера. После отсылки каждого  фрейма и получения на него ответа  запускается функция обработки ответа, которая 

проверяет какая команда введена и сколько фреймов уже переслано. Если количество фреймов оказывается меньше, чем должно быть для завершенной

команды она возвращает значение true, это значение получает функция send/4, которая изначально инициировала отправку фрейма, и в этом случае 

функция send/4  шлет следующий фрейм. В том случае когда для команды переслано нужное количество фреймов функция обработки ответов проверяет 

ответ на последний фрейм, и в зависимости от него решает нужно ли получить еще один фрейм для завершеного ответа. При ответе 'ok' может

быть достаточно одного фрейма. Если нужно посылает запрос на получения второго фрейма. И после получения оного весь ответ отправляется в

функцию вывода результата, которая выводит на экран результат и возвращает конечный ответ для API функций. В случае неожиданного ответа,

выводится сообщение об ошибке коммуникации с сервером.



                                                               Клиент

Для вынесенных API функций я реализовал консольный клиент. Команда и аргументы разделяются пробелами. Для того, чтобы получить из строки

бинарные значения 'Key' и 'Value' они должны быть введены в соответствии со стандартами Эрланга. И уже тогда на основе полученной строки 

в специальной функции после проверки корректности ввода генерируются бинарные данные для дальнейшей передачи в API функцию.  

Вот пример корректного ввода значения для бинарных данных: <<23, 230:16, "привет", "Hello":32>>	

Также проверяется значение времени для функции update на то, чтобы оно было целым положительным числом, и если оно соответствует, то

происходит коныертация этого значения из list в integer, и в API шлется уже integer. Запуск клиента: client:start().													   




--------------------------------------------------------------------------------------------------------------------------------------------

Необходимо создать сервис, представляющий собой Key-Value базу данных.

Ключи и значения могут являться совершенно абстрактыми данными.

У элементов БД может быть назначено "время жизни", по истечению которого элемент будет удаляться из БД.

БД должна обладать следующим функционалом:

- Создание таблиц
- Удаление таблиц
- Добавление/изменение элементов
- Удаление элементов
- Поиск элементов
  
Также БД должна отправлять уведомления об изменении элементов.

Исходный код должен быть представлен в виде форка данного репозитория.

Репозиторий должен содержать исходный код решения, тесты, необходимое описание для запуска.

Язык для реализации может быть любым из: C/C++/Python/Erlang.

# Техническая часть

Взаимодействие с БД должно происходить по ZMTP (соответственно желательно использовать библиотеку ZMQ).

Понадобиться как минимум 2 сокета:

- REP-сокет, служит для входящих соединений к БД
- PUB-сокет, служит для отправки уведомлений

Необходима поддержка нескольких одновременных подключений к БД.

Все операции над элементами БД должны быть атомарными.

# Описание протокола взаимодействия с БД

Взаимодействия с БД осуществляется через отправку ZMQ сообщений, состоящих из нескольких фреймов.

Первый фрейм это код команды. Последущие фреймы это аргументы команд.

В ответ на команды БД должна отправлять статус запроса (также ZMQ сообщение, состоящее из нескольких фреймов).

Необходимые команды и их структура:

| Синтаксис сообщений команд | Синтаксис сообщений ответа |
| --- | --- |
| `{CREATE_TABLE <TAB_NAME>}` | `{OK} \| {ERROR <REASON>}` |
| `{DELETE_TABLE <TAB_NAME>}` | `{OK} \| {ERROR <REASON>}` |
| `UPDATE <TAB_NAME> <KEY> <VALUE> [<TTL_SEC>]` | `{OK} \| {ERROR <REASON>}` |
| `DELETE <TAB_NAME> <KEY>` | `{OK <VALUE>} \| {ERROR <REASON>}` |
| `GET <TAB_NAME> <KEY>` | `{OK <VALUE>} \| {ERROR <REASON>}` |

Где:

- `CREATE_TABLE`, `DELETE_TABLE`, `UPDATE`, `DELETE`, `GET` - целые беззнаковые числа размером 1 байт (0, 1, 2, 3, 4 соответственно)
- `<TAB_NAME>` - строка до 255 байт (с учетом символа конца строки)
- `<KEY>`, `<VALUE>` - любые бинарные данные, ключ имеет ограничение на 64 байт, данные - 1 килобайт
- `<TTL_SEC>` - опциональный параметр, может отсутствовать. Целое беззнаковые число размером 64 байт - количество секунд

> **Замечание**: при обновлении данных, если не указан параметр TTL, TTL остается прежним. Если при добавлении TTL не был указан, то данные хранятся в таблице пока не будут удалены, или пока им не будет назначен TTL.

Структура сообщений уведомлений:

- `<TAB_NAME> UPDATED <KEY>`
- `<TAB_NAME> DELETED <KEY>`

Где:

- `UPDATED`, `DELETED` - целые беззнаковые числа размером 1 байт (0, 1 соответственно)
- `<TAB_NAME>` - строка до 255 байт (с учетом символа конца строки)
- `<KEY>` - любые бинарные данные, ключ имеет ограничение на 64 байт
