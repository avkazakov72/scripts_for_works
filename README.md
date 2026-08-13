# Коллекция моих скриптов для повседневных задач

## Структура

	pythonProjectNew.sh - создает новый рабочий прект в каталоге $HOME/PythonProject с заданным именем, создается и подключается 
виртуальное окружение, создаются базовые файлы и настройк.

		запуск: pythonProjectNew.sh PROJECT_NAME
	
	server_NFSconnect.sh - подключает настроеные на сервере NFS шары к данной машине в каталогт/mnt/SHARE/, по окончании работы отключает 
каталоги

## Установка скриптов
git clone https://github.com/avkazakov72/scripts_for_works.git
chmod +x scripts/*.sh
export PATH="$HOME/scripts:$PATH"
