#!/bin/bash

# new-python-project.sh - Создание нового Python проекта с виртуальным окружением

# Проверка аргументов
if [ -z "$1" ]; then
    echo "❌ Ошибка: Укажите имя проекта"
    echo "УКАЖИ ИМЯ ПРОЕКТА НА ЛАТИНСКОМ - ЭТО БУДЕТ ИМЕНЕМ КАТАЛОГА"
    echo "РАСПОЛОЖЕННОМ В ~/PythonProject"
    echo "Использование: $0 <имя_проекта>"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$HOME/PythonProject/$PROJECT_NAME"  # Можно изменить базовый путь

# Проверка, существует ли уже проект
if [ -d "$PROJECT_DIR" ]; then
    echo "❌ Ошибка: Проект '$PROJECT_NAME' уже существует в $PROJECT_DIR"
    exit 1
fi

echo "🚀 Создание Python проекта: $PROJECT_NAME"

# Создание директории проекта
mkdir -p "$PROJECT_DIR"
echo "✅ Создан каталог: $PROJECT_DIR"

# Переход в каталог проекта
cd "$PROJECT_DIR" || exit 1
echo "✅ Перешли в каталог проекта"

# Создание виртуального окружения
python3 -m venv .venv
echo "✅ Создано виртуальное окружение: .venv"

# Активация виртуального окружения (для текущей сессии)
source .venv/bin/activate
echo "✅ Виртуальное окружение активировано"

# Создание базовых файлов
echo "# $PROJECT_NAME" > README.md
echo "✅ Создан README.md"

# Создание .gitignore
cat > .gitignore << 'EOF'
# Виртуальное окружение
.venv/
venv/
env/
ENV/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
*.egg-info/
dist/
build/
*.egg

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
echo "✅ Создан .gitignore"

# Создание requirements.txt
touch requirements.txt
echo "✅ Создан requirements.txt"

# Создание main.py
cat > main.py << 'EOF'
#!/usr/bin/env python3
"""
Главный модуль проекта $PROJECT_NAME
"""

def main():
    print("🚀 Привет из проекта $PROJECT_NAME!")

if __name__ == "__main__":
    main()
EOF
echo "✅ Создан main.py"

# Вывод информации о проекте
echo ""
echo "=========================================="
echo "✅ Проект '$PROJECT_NAME' создан!"
echo "=========================================="
echo "📁 Каталог: $PROJECT_DIR"
echo "🐍 Python: $(python3 --version)"
echo "📦 Виртуальное окружение: активировано"
echo ""
echo "📝 Для активации виртуального окружения:"
echo "  cd $PROJECT_DIR"
echo "  source .venv/bin/activate"
echo ""
echo "📝 Для установки зависимостей:"
echo "  pip install -r requirements.txt"
echo ""
echo "🚀 Для запуска:"
echo "  python main.py"
echo "=========================================="

# Автоматически открываем VS Code (опционально)
if command -v code &> /dev/null; then
    read -p "Открыть проект в VS Code? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        code .
    fi
fi
