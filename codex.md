# Контекст разработки — Маяки в тумане

## Задача и источник истины

Реализовать локальные тикеты T01–T11 включительно по TDD. После каждого тикета сопоставлять наблюдаемый результат с каждым критерием. T12–T24 не входят в текущую задачу. Исходные требования: `docs/implementation-plan/{IDEA,SCOPE,ARCHITECTURE,ECONOMY,STATE-AND-SAVE,VERIFICATION}.md`, конкретные критерии — `tickets/Txx-*.md`. HTML-прототип не переносится.

## Текущее состояние

**Работа остановлена по просьбе пользователя. Следующая точка — T03, GREEN после уже наблюдённого RED. Один разрешённый сброс не использовался.**

- T01: коммит `8e9f9ba`; Godot 4.7.2 stable, проект, строгий раннер. Бинарник `/home/gra1mond/.local/bin/Godot_v4.7.2-stable_linux.x86_64`, SHA256 проверена. Оконный smoke: русский текст, пауза/продолжение при 1280×800; 205 FPS / 6.01 ms, WSL2 llvmpipe. Намеренная ошибка неиспользуемого скрипта дала exit 1.
- T02: коммит `86a4586`; GameSession, ProfileState, RunState, ContentCatalog, FixedClock. Три проверки `simulation` прошли. CLI-smoke: 40 → 41, повтор `cooldown`; 60 с на паузе оставили tick=0; продолжение → 42.
- T03: написан, но НЕ закоммичен `game/tests/cases/test_port.gd`. RED подтверждён: `Port construction must be available: unknown_command`, 1 тест / 1 ошибка. Следующий шаг — реализовать build port, w1, assign и реальную доставку 2+1+2 с через публичные команды; затем GREEN. Работников и производств ещё нет.
- T10: параллельно подготовлен НЕ закоммиченный `game/tests/cases/test_save.gd`; RED подтверждён отсутствующим SaveRepository. Самого `game/persistence/` пока нет. Это не выполненный T10.
- UI: НЕ закоммиченные изменения `game/world/main.gd` добавляют простую панель ресурсов/ручной сбор. НЕ закоммиченный `game/world/map_view.gd` написан фоновым агентом частично, НЕ проверен и ещё НЕ подключён; `game/ui/` отсутствует. Не считать карту реализацией T04.
- Фоновые агенты `NativeGameUI` и `ProfileStorage` отменены инструментом остановки; активной разработки нет. Не ждать от них дальнейшего результата.
- T04–T11 не выполнены. Не объявлять всю игру или демонстрацию готовой.

## Правила продолжения

- Одна вертикальная поведенческая проверка → наблюдаемый RED → минимальный GREEN. Не писать сразу весь набор тестов.
- Границы из VERIFICATION: `GameSession.dispatch/advance/snapshot`, `preview_prestige/prepare_prestige` с координатором фиксации, `SaveRepository.save/load`. Выбраны для выполнения запроса пользователя от 2026-11-03; это рабочее решение реализации, не отдельный ответ пользователя о seams.
- Состоянием владеет GameSession; UI отправляет команды и читает независимые снимки. Никаких команд выдачи ресурсов для прохождения.
- Шаг 0.1 с, ручной сбор ограничен игровым временем. Закрытая игра не производит ресурсы.
- Полный профиль сохраняется одной операцией. Ошибка престижа не меняет активный профиль. Tmp не восстанавливается; будущая основная версия блокирует загрузку и autosave.
- После изменения тикета: запуск, критерии, короткая запись доказательств; затем следующий тикет. Не отмечать Windows-проверки выполненными без Windows-запуска.
- Перед разрешённым пользователем одним сбросом обновить этот файл: точный тикет, результаты, команды и следующий шаг.

## Архитектура

`game/`: Godot 4, типизированный GDScript, Compatibility, 1280×800. `core/` — правила и состояние; `content/` — единый каталог чисел; `world/` и `ui/` — карта и управление; `persistence/` — полный профиль; `tests/` — headless-проверки публичных границ.

## Контракты данных

Реализованный контракт T02: `GameSession.new_profile(seed)`, `dispatch(Dictionary) -> {accepted,reason_code,events}`, `advance(seconds)`, `snapshot()` (глубокая копия профиля + paused/derived), `export_profile()`. Команды пока только collect/pause. Профиль: schema_version/content_version/revision/profile_id, meta и run. Meta: total_echo, allocation engineering/economy/specialization, claimed_milestone_ids, discovered_locations, story_flags, cycle_index, automation_preferences. Run: run_id,seed,tick,wallet,lifetime_produced,last_collect_tick,stations,workers,upgrades,goals,finds,project_stages,beam_target,oil_boost_target,oil_boost_enabled,generator_enabled. Шесть ресурсов — alloy/oil/quartz/biomass/data/resonance. stations/workers пока пустые. Значения последующих тикетов ниже — план, НЕ уже работающий API.

## Проверки и ограничения

`GODOT=/home/gra1mond/.local/bin/Godot_v4.7.2-stable_linux.x86_64 python3 scripts/check.py [--case NAME|--parse-only]`. T01: 1/1, оконный запуск подтверждён; T02: simulation 3/3 и CLI-smoke. Полный набор при остановке намеренно содержит RED T03/T10; не считать его зелёным. LSP не настроен; раннер компилирует каждый .gd. Windows-запуск и файловые гарантии Windows требуют отдельной проверки на этой ОС. Снимок T01: `/tmp/lighthouse-t01.png`; временный CLI smoke: `/tmp/lighthouse-session-smoke.gd`. `game/tests/smoke_ui.gd` и UI-тест T01 требуют пересмотра после замены main: не перепривязывать проверки к внутренним методам новой сцены.

## Следующий запуск

1. Прочитать этот файл, T03 и `game/tests/cases/test_port.gd`; учесть незакоммиченные файлы выше. Не начинать с нового проекта и не откатывать рабочие изменения.
2. Продолжить T03 с уже наблюдённого RED. Проверять по одному поведению: доставка, возврат на разных фазах, покупка, два маршрута.
3. После GREEN и запуска обновить конкретный тикет и этот файл, сделать отдельный коммит с ID. Следовать T04 → T11, не перескакивать на неподтверждённый UI.
4. После возобновления проверить синтаксис частичного `map_view.gd`, прежде чем включать его в сцену. Текущие `.gd.uid` от импорта — штатные Godot-файлы; оставшиеся временные smoke-файлы убрать после замены окончательными сценариями.

## Согласованный рабочий дизайн следующих срезов (ещё не реализован)

Детальный контракт передачи агентам был в `local://lighthouse-contract.md`; ниже сохранены ключевые решения для нового сеанса.

- Один GameSession владеет профилем; будущий GameCoordinator соединяет session и repository. UI вызывает coordinator.dispatch/frame/save/confirm_prestige и читает session.snapshot. Цены/эффекты/скорости предоставляет derived, UI не копирует формулы.
- Station ID: port,oil,quartz_1,quartz_2 и далее; поля id,kind,region,enabled,power_request,priority,mode,phase,phase_progress,heat. Фазы: port idle (маршрут у работника), oil pressure/pumping/cooling, quartz charge/fracture/cooling. Worker: id,assignment,queued_assignment,queued_target,target near/far,phase idle/outbound/loading/returning/research,phase_progress,cargo,recall_pending. port/research могут иметь несколько работников; oil/отдельный бур — одного. При возврате старое назначение остаётся до доставки, затем применяется очередь. Работник без груза возвращается без выплаты; переносимый груз выдаётся один раз по прибытии.
- Дополнить RunState: relays, generator_built, automation_enabled. Реле: port/oil/quartz/coastal, поля built/enabled. Строительство станции включает реле района без второй скрытой цены. Позиции ship[0,0],port[160,0],oil[0,160],quartz[320,0],coastal[480,0], дальность160. Цепочки ship→port→quartz→coastal и ship→oil.
- Будущие команды: build{kind:port/oil/quartz/generator}, buy_worker, assign{worker,station,target}, recall{worker}, target{worker,target}, beam{target}, relay{region,enabled}, station_enabled{station,enabled}, power{station,request,priority}, mode{station,mode}, generator{enabled}, oil_boost{target,enabled}, research{id}, project{id:coastal_beacon}, automation{enabled}. collect/pause уже работают.
- Исследования: capacity/stability/optics/automation/lens, предельные уровни 3/3/2/1/2. goals.coastal_beacon bool; project_stages.coastal_beacon 0/1; finds пока пустой; story_flags допускают coastal_beacon.
- Будущие derived: regions[ship/port/oil/quartz/coastal] с discovered/unlocked/built/connected/active,position,reason,name; stations с reason/active/power/rate/phase/progress/cycle_seconds/output и oil pressure/heat_limit; links; power_capacity/power_used; oil_production/consumption/net/seconds; next_goal; prices; upgrades{name,level,max_level,cost,effect,available}; prestige_available. Для анимации workers[id]{progress,phase_seconds,capacity,routes:{near/far:{cargo,travel_seconds,loading_seconds,cycle_seconds,rate}}}. beam_effects[port/oil/quartz]{name,effect}, oil_boost{target,enabled,active,consumption,bonus,effect}, generator{built,enabled,active,consumption,capacity,reason}.
- Будущий SaveRepository.new(directory=\"user://profile\"): save(profile)->{ok,reason_code,revision}, load()->{ok,reason_code,profile,recovered,blocked}; validate_profile()->{ok,reason_code,profile с defaults}. Файлы profile.json/profile.tmp/profile.bak.json. Same revision + identical idempotent; same revision + changed => revision_conflict; old => stale_revision. Tmp никогда не кандидат. Будущая версия primary блокирует старый backup и save. Неподдерживаемый backup сохранять и консервативно блокировать перезапись. Валидация ID/типов/чисел/назначений. Проверять реальные filesystem-ошибки, не вводить флаг «притвориться неудачей».
- Будущий престиж: preview_prestige(allocation)->{accepted,reason_code,preview_id,reward,total_echo,milestone_ids,allocation,lost,kept,next_milestone}; prepare_prestige(id)->{accepted,reason_code,profile}. Coordinator сохраняет кандидата ДО замены активного профиля. Milestone IDs: first_port/first_oil/first_quartz/coastal_beacon (1/1/1/2 эхо), дополнительные alloy_500/oil_150/quartz_80 по1. Предварительные цены перков engineering2/economy1/specialization2 за уровень, максимум2; окончательные значения согласовать с ECONOMY в T11.
- Неразрешённый UX-вопрос престижа: preview ID привязан к revision, поэтому окно подготовки должно приостанавливать симуляцию безопасно (сохранив/восстановив прежнюю паузу) либо явно отклонять устаревший preview. Не подменять показанную награду тихим пересчётом на подтверждении.
