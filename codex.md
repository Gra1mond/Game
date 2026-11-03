# Контекст разработки — Маяки в тумане

## Задача и источник истины

Реализовать локальные тикеты T01–T11 включительно по TDD. После каждого тикета сопоставлять наблюдаемый результат с каждым критерием. T12–T24 не входят в текущую задачу. Исходные требования: `docs/implementation-plan/{IDEA,SCOPE,ARCHITECTURE,ECONOMY,STATE-AND-SAVE,VERIFICATION}.md`, конкретные критерии — `tickets/Txx-*.md`. HTML-прототип не переносится.

## Текущее состояние

**T03 реализован и проверен. Ветка `feat/T03-port`; следующий шаг — передать PR в `dev` и ждать явного подтверждения пользователя. T04 не начинать до подтверждения. Автопродление не использовалось.**

- T01: коммит `8e9f9ba`; Godot 4.7.2 stable, проект, строгий раннер. Бинарник `/home/gra1mond/.local/bin/Godot_v4.7.2-stable_linux.x86_64`, SHA256 проверена. Оконный smoke: русский текст, пауза/продолжение при 1280×800; 205 FPS / 6.01 ms, WSL2 llvmpipe. Намеренная ошибка неиспользуемого скрипта дала exit 1.
- T02: коммит `86a4586`; GameSession, ProfileState, RunState, ContentCatalog, FixedClock. Три проверки `simulation` прошли. CLI-smoke: 40 → 41, повтор `cooldown`; 60 с на паузе оставили tick=0; продолжение → 42.
- T03: порт20 сплава, w1 на старте, покупка работников12/17/…, два возобновляемых маршрута, реальные фазы 2+1+2 / 3+2+3, возврат и очередь переназначения. Локальное оснащение cargo_hold за16 увеличивает трюм4→8; near ограничен4, far12. Уже погруженный груз не меняется. Реализация: `core/port_rules.gd`, команды в GameSession, `world/main.gd`, `world/port_view.gd`.
- Проверки: полный `scripts/check.py` **11/11** (port8 + simulation3). Для шести основных новых поведений наблюдались отдельные RED → GREEN. Два настоящих оконных smoke-сценария проверили доставку4/8, паузу, клавиатуру с фокусом кнопки, удержание ручного сбора и сообщение о нехватке; снимки просмотрены.
- Удалены собственные преждевременные незакоммиченные черновики T04 `map_view.gd` и T10 `test_save.gd`, а также временный smoke T01 и тест приватного метода/формулировки паузы. В наборе нет теста несуществующего SaveRepository; его реализацию и RED начать заново в T10. Это не выполненный T10.
- Активных фоновых агентов нет. GitHub авторизован через Windows `gh.exe`; API-запрос к репозиторию успешен. `dev` создана от удалённой main. Этот первый PR включает базовые T01–T02, поскольку раньше PR в dev не было. Отдельный Linux `gh` отсутствует; Windows `gh` не находит Git в своём PATH, поэтому Git-операции выполняет Linux git.
- T04–T11 не выполнены. Не объявлять всю игру или демонстрацию готовой.

## Правила продолжения

- Одна вертикальная поведенческая проверка → наблюдаемый RED → минимальный GREEN. Не писать сразу весь набор тестов.
- Границы из VERIFICATION: `GameSession.dispatch/advance/snapshot`, `preview_prestige/prepare_prestige` с координатором фиксации, `SaveRepository.save/load`. Выбраны для выполнения запроса пользователя от 2026-11-03; это рабочее решение реализации, не отдельный ответ пользователя о seams.
- Состоянием владеет GameSession; UI отправляет команды и читает независимые снимки. Никаких команд выдачи ресурсов для прохождения.
- Шаг 0.1 с, ручной сбор ограничен игровым временем. Закрытая игра не производит ресурсы.
- Полный профиль сохраняется одной операцией. Ошибка престижа не меняет активный профиль. Tmp не восстанавливается; будущая основная версия блокирует загрузку и autosave.
- После каждого тикета: завершить реализацию, выполнить проверки и запуск, сверить все критерии, обновить тикет и этот файл, сделать отдельный коммит с ID, push рабочей ветки и открыть pull request с целевой веткой `dev`. Отправить пользователю ссылку и результаты, явно попросить подтверждение. До явного подтверждения пользователя ЖДАТЬ: не начинать следующий тикет и не сливать PR самостоятельно. Это правило задано пользователем после остановки и заменяет автоматический переход к следующему тикету. Не отмечать Windows-проверки выполненными без Windows-запуска.
- Перед автопродлением при исчерпании токенов ВСЕГДА спрашивать разрешение и ждать ответа (последнее уточнение пользователя). Ранее разрешённый один сброс не заменяет это подтверждение. Перед разрешённым продолжением сохранить здесь текущий тикет, результаты, команды и следующий шаг; не обещать изменение лимитов платформы.

## Архитектура

`game/`: Godot 4, типизированный GDScript, Compatibility, 1280×800. `core/` — правила и состояние; `content/` — единый каталог чисел; `world/` и `ui/` — карта и управление; `persistence/` — полный профиль; `tests/` — headless-проверки публичных границ.

## Контракты данных

Реализованный контракт T03: `GameSession.new_profile(seed)`, `dispatch(Dictionary) -> {accepted,reason_code,events}`, `advance(seconds)`, `snapshot()` (глубокая копия профиля + paused/derived), `export_profile()`, `is_paused()`. Команды: collect, pause{paused}, build{kind:port}, buy_worker, assign{worker,station:port,target:near/far}, recall{worker}, upgrade{id:cargo_hold}. Профиль schema/content_version=1, revision/profile_id, meta и run; остальные ресурсы/метаполя пока не используются. В workers есть w1 и купленные w2…; fields id/assignment/target/phase/phase_progress/cargo/recall_pending/queued_assignment/queued_target. stations.port после покупки — id/kind/enabled. PortRules.describe формирует derived.workers/routes/upgraded_routes/stations/prices/upgrades/capacity/power_capacity/power_used. Цены и формулы не копировать в UI. Подробные defaults — STATE-AND-SAVE; значения последующих тикетов ниже пока план.

## Проверки и ограничения

`GODOT=/home/gra1mond/.local/bin/Godot_v4.7.2-stable_linux.x86_64 python3 scripts/check.py [--case port|--case simulation|--parse-only]`. Последний полный запуск: все `.gd` компилируются и **11/11** проходят. LSP не настроен. Native smoke: Godot4.7.2,1280×800,WSL2/llvmpipe; снимки `/tmp/lighthouse-t03-returning.png`, `/tmp/lighthouse-t03-shortage.png`, `/tmp/lighthouse-t03-upgrade.png` просмотрены. Windows-бинарник/экспорт и сохранения пока не проверены; закрытие игры до T10 теряет текущую экспедицию. Временные CLI/UI smoke-сценарии не коммитятся.

## Следующий запуск

1. Прочитать этот файл и статус PR T03 в `dev`. Без явного подтверждения пользователя не выполнять T04; автоматическое слияние запрещено.
2. После подтверждения начать T04 от принятой базы: карта, реле, дальность и распределение питания. Сначала публичный поведенческий RED, затем реализация. Черновой `map_view.gd` был удалён; работающая визуализация T03 — `port_view.gd`.
3. После каждого тикета: критерии → проверки/оконный запуск → обновление тикета/codex → отдельный коммит → push → PR в dev → ссылка пользователю и ожидание подтверждения. Порядок после подтверждений: T04 → T11.
4. При добавлении сохранений учесть реальные поля работника и upgrades.cargo_hold. Не считать настройки/престиж/сеть реализованными из-за их упоминания в плане.

## Согласованный рабочий дизайн следующих срезов (ещё не реализован)

Детальный контракт передачи агентам был в `local://lighthouse-contract.md`; ниже сохранены ключевые решения для нового сеанса.

- Сейчас UI отправляет команды непосредственно GameSession; в T10 будущий GameCoordinator соединит session/repository и возьмёт dispatch/frame/save/confirm_prestige. Один GameSession остаётся владельцем профиля. Цены/эффекты/скорости формирует derived, UI не копирует экономические формулы.
- Station ID: port,oil,quartz_1,quartz_2 и далее; поля id,kind,region,enabled,power_request,priority,mode,phase,phase_progress,heat. Фазы: port idle (маршрут у работника), oil pressure/pumping/cooling, quartz charge/fracture/cooling. Worker: id,assignment,queued_assignment,queued_target,target near/far,phase idle/outbound/loading/returning/research,phase_progress,cargo,recall_pending. port/research могут иметь несколько работников; oil/отдельный бур — одного. При возврате старое назначение остаётся до доставки, затем применяется очередь. Работник без груза возвращается без выплаты; переносимый груз выдаётся один раз по прибытии.
- Дополнить RunState: relays, generator_built, automation_enabled. Реле: port/oil/quartz/coastal, поля built/enabled. Строительство станции включает реле района без второй скрытой цены. Позиции ship[0,0],port[160,0],oil[0,160],quartz[320,0],coastal[480,0], дальность160. Цепочки ship→port→quartz→coastal и ship→oil.
- Дополнения к уже реализованным командам T03: build{kind:oil/quartz/generator}, назначения на новые станции, beam{target}, relay{region,enabled}, station_enabled{station,enabled}, power{station,request,priority}, mode{station,mode}, generator{enabled}, oil_boost{target,enabled}, research{id}, project{id:coastal_beacon}, automation{enabled}. Не вводить дублирующую команду target для уже работающего assign без необходимости.
- Исследования T08: capacity/stability/optics/automation/lens, предельные уровни пока план3/3/2/1/2; cargo_hold уже существует как оснащение T03, не переименовывать его молча в исследование. goals.coastal_beacon bool; project_stages.coastal_beacon 0/1; finds пока пустой; story_flags допускают coastal_beacon.
- Будущие derived: regions[ship/port/oil/quartz/coastal] с discovered/unlocked/built/connected/active,position,reason,name; stations с reason/active/power/rate/phase/progress/cycle_seconds/output и oil pressure/heat_limit; links; power_capacity/power_used; oil_production/consumption/net/seconds; next_goal; prices; upgrades{name,level,max_level,cost,effect,available}; prestige_available. Для анимации workers[id]{progress,phase_seconds,capacity,routes:{near/far:{cargo,travel_seconds,loading_seconds,cycle_seconds,rate}}}. beam_effects[port/oil/quartz]{name,effect}, oil_boost{target,enabled,active,consumption,bonus,effect}, generator{built,enabled,active,consumption,capacity,reason}.
- Будущий SaveRepository.new(directory=\"user://profile\"): save(profile)->{ok,reason_code,revision}, load()->{ok,reason_code,profile,recovered,blocked}; validate_profile()->{ok,reason_code,profile с defaults}. Файлы profile.json/profile.tmp/profile.bak.json. Same revision + identical idempotent; same revision + changed => revision_conflict; old => stale_revision. Tmp никогда не кандидат. Будущая версия primary блокирует старый backup и save. Неподдерживаемый backup сохранять и консервативно блокировать перезапись. Валидация ID/типов/чисел/назначений. Проверять реальные filesystem-ошибки, не вводить флаг «притвориться неудачей».
- Будущий престиж: preview_prestige(allocation)->{accepted,reason_code,preview_id,reward,total_echo,milestone_ids,allocation,lost,kept,next_milestone}; prepare_prestige(id)->{accepted,reason_code,profile}. Coordinator сохраняет кандидата ДО замены активного профиля. Milestone IDs: first_port/first_oil/first_quartz/coastal_beacon (1/1/1/2 эхо), дополнительные alloy_500/oil_150/quartz_80 по1. Предварительные цены перков engineering2/economy1/specialization2 за уровень, максимум2; окончательные значения согласовать с ECONOMY в T11.
- Неразрешённый UX-вопрос престижа: preview ID привязан к revision, поэтому окно подготовки должно приостанавливать симуляцию безопасно (сохранив/восстановив прежнюю паузу) либо явно отклонять устаревший preview. Не подменять показанную награду тихим пересчётом на подтверждении.
