# Маяки в тумане

Godot 4.7.2 stable (`4.7.2.stable.official.ed1daf0bf`), типизированный GDScript, 2D Compatibility. Целевая платформа — Windows x64. Исходный HTML остаётся отдельным экспериментом.

## Установка и запуск

Скачайте официальный **Godot 4.7.2 stable Standard**, не .NET: [релиз](https://github.com/godotengine/godot/releases/tag/4.7.2-stable). Распакуйте архив для своей ОС; добавьте каталог в PATH или задайте полный путь. Для экспорта нужны **export templates 4.7.2 stable**, установка через Editor → Manage Export Templates. Экспорт и архив Windows относятся к T24.

```powershell
$env:GODOT = "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
& $env:GODOT --editor --path game
& $env:GODOT --path game
py scripts/check.py
py scripts/check.py --case simulation
```

```sh
# Linux/WSL; здесь установлен официальный бинарник с проверенной SHA256
export GODOT="$HOME/.local/bin/Godot_v4.7.2-stable_linux.x86_64"
"$GODOT" --editor --path game
"$GODOT" --path game
python3 scripts/check.py
python3 scripts/check.py --case simulation
python3 scripts/check.py --parse-only
```

`GODOT` по умолчанию — `godot`. Python 3 — только инструмент проверки, не зависимость игры. Проверка импортирует проект, компилирует **все** `.gd`, включая неиспользуемые сценой, затем запускает поведенческие сценарии. Ошибки в логе Godot также дают ненулевой статус. Неизвестный/пустой набор проверок считается ошибкой. Проверки сохранений используют отдельные временные каталоги.

## Управление

Пауза — кнопка или пробел. Остальное управление добавляется по тикетам; текущее состояние и подтверждённые проверки — `codex.md` и локальные тикеты в `docs/implementation-plan/tickets/`.

## Эталон T01

WSL2 Linux x86_64, Intel Core Ultra 5 125H, 18 логических CPU; Compatibility / Mesa llvmpipe LLVM 20.1.2 (software rendering), окно 1280×800. Оконный запуск пустой карты: 205 FPS, последний process frame 6.01 ms после двух секунд; это начальный диагностический замер, не гарантия производительности полной игры. Русский экран паузы визуально проверен, продолжение сработало. Намеренная ошибка в неиспользуемом `.gd` обнаружена `scripts/check.py` с exit 1; временный файл удалён. Windows-запуск и экспорт в этом окружении пока не проверены.
