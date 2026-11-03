# Контекст разработки — Маяки в тумане

## Задача и источник истины

Реализовать локальные тикеты T01–T11 включительно по TDD. После каждого тикета сопоставлять наблюдаемый результат с каждым критерием. T12–T24 не входят в текущую задачу. Исходные требования: `docs/implementation-plan/{IDEA,SCOPE,ARCHITECTURE,ECONOMY,STATE-AND-SAVE,VERIFICATION}.md`, конкретные критерии — `tickets/Txx-*.md`. HTML-прототип не переносится.

## Текущее состояние

**T04 реализован, проверен и опубликован: [PR #2 в dev](https://github.com/Gra1mond/Game/pull/2), ветка `feat/T04-network`, реализация `0db75c6`. ЖДАТЬ явного подтверждения пользователя перед T05; PR самостоятельно не сливать. PR #1 T03 уже слит. Автопродление не использовалось.**

- T01: коммит `8e9f9ba`; Godot 4.7.2 stable, проект, строгий раннер. Бинарник `/home/gra1mond/.local/bin/Godot_v4.7.2-stable_linux.x86_64`, SHA256 проверена. Оконный smoke: русский текст, пауза/продолжение при 1280×800; 205 FPS / 6.01 ms, WSL2 llvmpipe. Намеренная ошибка неиспользуемого скрипта дала exit 1.
- T02: коммит `86a4586`; GameSession, ProfileState, RunState, ContentCatalog, FixedClock. Три проверки `simulation` прошли. CLI-smoke: 40 → 41, повтор `cooldown`; 60 с на паузе оставили tick=0; продолжение → 42.
- T03: порт20 сплава, w1 на старте, покупка работников12/17/…, два возобновляемых маршрута, реальные фазы 2+1+2 / 3+2+3, возврат и очередь переназначения. Локальное оснащение cargo_hold за16 увеличивает трюм4→8; near ограничен4, far12. Уже погруженный груз не меняется. Реализация: `core/port_rules.gd`, команды в GameSession, `world/main.gd`, `world/port_view.gd`.
- Проверки T03: 11/11 (port8+simulation3), отдельные RED→GREEN для шести основных поведений; оконные сценарии доставки4/8, паузы, удержания ручного сбора и нехватки ресурсов.
- Удалены собственные преждевременные незакоммиченные черновики T04 `map_view.gd` и T10 `test_save.gd`, а также временный smoke T01 и тест приватного метода/формулировки паузы. В наборе нет теста несуществующего SaveRepository; его реализацию и RED начать заново в T10. Это не выполненный T10.
- Активных фоновых агентов нет. GitHub авторизован через Windows `gh.exe`; Windows CLI не видит Git в PATH, поэтому Git-операции выполняет Linux git. Первый PR #1 (T03) включал базу T01–T02; он уже слит, T04 начат от принятой dev.
- Push `feat/T04-network` успешен: `git -c credential.helper= -c 'credential.helper=!"/mnt/c/Program Files/GitHub CLI/gh.exe" auth git-credential' push -u origin feat/T04-network`. Токены не выводить/не записывать в проект. PR создан через `gh.exe api`; новый вход не нужен. Перед следующим тикетом проверить PR #2 и ответ пользователя.
- T04: `NetworkRules.evaluate` распределяет бюджет среди доступных из активной цепочки потребителей, приоритет→стабильный ID. run.relays и отдельные station/relay-потребители, физическая остановка порта с сохранением фазы. Новые команды build_relay/relay/station_enabled/power. MapView и вкладка питания работают через snapshot/dispatch.
- Проверки T04: полный набор **18/18** (network7+port8+simulation3), все `.gd` компилируются. Реальный оконный smoke проверил выбор мышью, колесо/клавиатуру, три реле, разрыв/восстановление, скрытый порт, дефицит и смену приоритета. При дефиците неизменны и данные работника, и пиксели PortView; после восстановления доставка один раз. Снимки просмотрены. Финальный smoke ожидает реальные tick; ранний повтор с настенными таймерами не попал в ожидаемую фазу.
- Агенты RelayAllocator/NetworkMapUI завершили работу; активных фоновых задач нет. T05–T11 не выполнены. Реле на oil/quartz/coastal не означают готовую добычу или Береговой проект.

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

Реализованный контракт T04: GameSession new_profile/dispatch/advance/snapshot/export_profile/is_paused. Команды T03 сохранены. Добавлены `build_relay{region}`, `relay{region,enabled:bool}`, `station_enabled{station,enabled:bool}`, `power{station:consumer_id,request:number,priority:int}`. consumer_id=`port` либо `relay:<region>`. run.relays по умолчанию{}; запись built/enabled=true, power_request=.25, priority=10. Станция port имеет region=port,power_request=.75,priority=0,enabled=true.

Каталог: дальность160 включительна, аварийное питание2; ship(0,0),port(160,0),oil(0,160),quartz(320,0),coastal(480,0). Цена port-реле10,oil10,quartz12,coastal16; цена станции20 включает port-реле (после отдельного реле доплата10). Запрос0…2; ниже минимального потребитель не работает и не расходует мощность; приоритет−100…100 целым.

GameSession кэширует NetworkRules после новых/изменённых сетевых состояний, не каждый tick. Snapshot возвращает отдельные copies derived.regions/consumers/links/range/power_limits/power_capacity/power_used/prices.relays. Фактическое питание станции разрешает PortRules.advance; отключение не сбрасывает фазы/груз. Обнаружение острова сохраняется при разрыве. UI выбор/масштаб/сдвиг не входят в профиль.

## Проверки и ограничения

`GODOT=/home/gra1mond/.local/bin/Godot_v4.7.2-stable_linux.x86_64 python3 scripts/check.py [--case network|--case port|--case simulation|--parse-only]`. Полный запуск **18/18**. Native smoke: Godot4.7.2,1280×800,WSL2/llvmpipe. Снимки `/tmp/lighthouse-t04-disconnected.png`, `/tmp/lighthouse-t04-no-power.png`, `/tmp/lighthouse-t04-restored.png` просмотрены. Оконный итог: запас4/выпуск22/мощность1.5из2. Временный smoke не коммитится. LSP отсутствует. Windows-бинарник/экспорт и сохранения не проверены; закрытие до T10 теряет экспедицию.

## Следующий запуск

1. Проверить статус PR T04 и явный ответ пользователя. Без подтверждения не выполнять T05 и не сливать PR автоматически.
2. После подтверждения начать T05 от принятой dev: управляемый главный луч, направление с карты и панели, реальный эффект на порт; базовая сеть остаётся самостоятельной.
3. После каждого тикета: критерии → проверки/оконный запуск → документация/codex → коммит → push → PR в dev → ссылка и ожидание подтверждения. Далее T05 → T11.
4. В T06 генератор должен менять фактическую capacity в NetworkRules до производства шага. В T10 сериализовать реальные relays/stations/очередь возврата/cargo_hold, но не пересчитываемый кэш. Промышленный порог T07 отдельно от `regions.unlocked`, который в T04 означает только доступность реле.

## Согласованный рабочий дизайн следующих срезов (ещё не реализован)

Детальный контракт передачи агентам был в `local://lighthouse-contract.md`; ниже сохранены ключевые решения для нового сеанса.

- Сейчас UI отправляет команды непосредственно GameSession; в T10 будущий GameCoordinator соединит session/repository и возьмёт dispatch/frame/save/confirm_prestige. Один GameSession остаётся владельцем профиля. Цены/эффекты/скорости формирует derived, UI не копирует экономические формулы.
- Station ID: port,oil,quartz_1,quartz_2 и далее; поля id,kind,region,enabled,power_request,priority,mode,phase,phase_progress,heat. Фазы: port idle (маршрут у работника), oil pressure/pumping/cooling, quartz charge/fracture/cooling. Worker: id,assignment,queued_assignment,queued_target,target near/far,phase idle/outbound/loading/returning/research,phase_progress,cargo,recall_pending. port/research могут иметь несколько работников; oil/отдельный бур — одного. При возврате старое назначение остаётся до доставки, затем применяется очередь. Работник без груза возвращается без выплаты; переносимый груз выдаётся один раз по прибытии.
- В следующих тикетах дополнить RunState generator_built/automation_enabled и районными полями. relays и распределение питания уже реализованы в T04, не создавать второй независимый граф или второе значение мощности.
- Дополнения T05+: build{kind:oil/quartz/generator}, назначения на новые станции, beam{target}, mode{station,mode}, generator{enabled}, oil_boost{target,enabled}, research{id}, project{id:coastal_beacon}, automation{enabled}. relay/station_enabled/power уже работают; не дублировать assign отдельной командой target без необходимости.
- Исследования T08: capacity/stability/optics/automation/lens, предельные уровни пока план3/3/2/1/2; cargo_hold уже существует как оснащение T03, не переименовывать его молча в исследование. goals.coastal_beacon bool; project_stages.coastal_beacon 0/1; finds пока пустой; story_flags допускают coastal_beacon.
- Будущие derived: районные фазы/прогнозы, oil_production/consumption/net/seconds, next_goal, исследования, prestige_available; beam_effects[port/oil/quartz]{name,effect}, oil_boost{target,enabled,active,consumption,bonus,effect}, generator{built,enabled,active,consumption,capacity,reason}. Не дублировать уже существующие regions/consumers/links/workers/prices и power-показатели.
- Будущий SaveRepository.new(directory=\"user://profile\"): save(profile)->{ok,reason_code,revision}, load()->{ok,reason_code,profile,recovered,blocked}; validate_profile()->{ok,reason_code,profile с defaults}. Файлы profile.json/profile.tmp/profile.bak.json. Same revision + identical idempotent; same revision + changed => revision_conflict; old => stale_revision. Tmp никогда не кандидат. Будущая версия primary блокирует старый backup и save. Неподдерживаемый backup сохранять и консервативно блокировать перезапись. Валидация ID/типов/чисел/назначений. Проверять реальные filesystem-ошибки, не вводить флаг «притвориться неудачей».
- Будущий престиж: preview_prestige(allocation)->{accepted,reason_code,preview_id,reward,total_echo,milestone_ids,allocation,lost,kept,next_milestone}; prepare_prestige(id)->{accepted,reason_code,profile}. Coordinator сохраняет кандидата ДО замены активного профиля. Milestone IDs: first_port/first_oil/first_quartz/coastal_beacon (1/1/1/2 эхо), дополнительные alloy_500/oil_150/quartz_80 по1. Предварительные цены перков engineering2/economy1/specialization2 за уровень, максимум2; окончательные значения согласовать с ECONOMY в T11.
- Неразрешённый UX-вопрос престижа: preview ID привязан к revision, поэтому окно подготовки должно приостанавливать симуляцию безопасно (сохранив/восстановив прежнюю паузу) либо явно отклонять устаревший preview. Не подменять показанную награду тихим пересчётом на подтверждении.
