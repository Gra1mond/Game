# T24 — Локальная Windows-сборка

Статус: запланирован. Веха: M2.

## Основная идея

Готовую игру можно передать человеку без редактора и инструкций разработчика.

## Цель

Получен воспроизводимый архив Windows x64 с рабочим новым стартом и продолжением.

## Входные условия

Завершены: [T23](T23-stability.md).

Прочитать [IDEA](../IDEA.md), [SCOPE](../SCOPE.md), [архитектуру](../ARCHITECTURE.md), [состояние](../STATE-AND-SAVE.md), [экономику](../ECONOMY.md) и [проверки](../VERIFICATION.md). При противоречии сначала актуализировать общий договор в [DECISIONS](../DECISIONS.md).

Обязательны [ART-AND-ASSETS](../ART-AND-ASSETS.md) и происхождение/ограничения инструментов в [SKILLS-RESEARCH](../SKILLS-RESEARCH.md); gameplay экипажа/талантов — [CREW-AND-TALENTS](../CREW-AND-TALENTS.md).

## Входит в тикет

- Экспортный preset, сборка, содержимое архива, номер версии и инструкция запуска.
- Проверка чистого запуска, сохранений, credits/лицензий, runtime GLB/PBR/PNG/персонажей/карточек и честного списка известных ограничений.

## За границами тикета

Публикация в Steam, загрузка внешних файлов, коммерческие настройки и Steam API.

## Необходимые детали реализации

- Точная версия движка/Windows export templates из T01 (Godot 4.7.2), preset/renderer Compatibility, команда и зависимости документированы; наличие Linux binary не доказывает наличие templates и Windows export.
- Отладочные выдачи ресурсов и изменение скорости скрыты в release; обычное меню/пауза доступны. Игра не вызывает Blender/bpy/MPFB/MCP, Python art scripts, генеративные API или сеть для отображения моделей; готовые GLB/baked PBR/PNG входят в поставку.
- Source `.blend`, authoring scripts/locks и исходные asset packs сохраняются отдельно для воспроизводимости, не требуются игроку. В runtime-архив включать только нужные outputs и notices; не включать личные сохранения, `.godot`, секреты/ключи, исходные reference photos и рабочие журналы.
- Manifest связывает поставляемые outputs с источником/версией/recipe/license; credits/attribution включают требуемые notices для конкретных meshes/textures/fonts/audio, не только MIT/GPL плагина. Условия third-party packs и CC-BY учтены индивидуально.
- На Windows проверить настоящую карту и native 3D-карточку, все типы/версии моделей, upgrade, crew/stats, pause/reduced motion, один preview и отсутствие hidden rendering. Измерить тяжёлую сцену в экспортированной сборке с точными hardware/OS/driver/resolution/renderer и сравнением T12A/T20 бюджетов.
- Недоступность Windows/hardware/templates указывается точным блокером, а не успешной приёмкой. Linux/WSL/headless parsing или чужой upstream report не заменяют native Windows запуск и фактическое отображение; такой пункт не может считаться закрытым release gate.

## Критерии приёмки

- [ ] Экспортированная игра запускается на Windows x64 без редактора, Blender/MPFB/MCP/Python/API-ключей/сети; новый профиль и продолжение работают.
- [ ] Архив имеет версию и контрольную сумму, экспорт воспроизводим по инструкции из подготовленных runtime outputs; source-to-output recipe/lock/manifest сохранён отдельно.
- [ ] Все модели/текстуры/PNG и персонажи реально видны в Windows Compatibility без missing dependencies; successful upgrade, достоверные stats/crew, reduced motion/rotation pause и hidden-preview budget проверены.
- [ ] Лицензии, credits и attribution полны для каждого поставляемого компонента; нет приватных файлов, ненужных source/tool dependencies и платного generator runtime.
- [ ] Финальный предсохранённый сценарий проходит в сборке; фактические Windows render/performance доказательства и известные проблемы записаны честно. Непроверенная Windows часть блокирует закрытие T24.

## Проверка

Полный набор один раз после финальных изменений; smoke чистого профиля/выхода/загрузки/финала в экспортированной Windows-сборке на машине без authoring toolchain. Фактические render captures всех типов карточек, meaningful upgrade, pause/reduced motion и метрики baseline/open/upgrade/hidden на тяжёлой карте; сверка состава архива/manifest/notices. Записать ОС/hardware/driver/renderer/templates и выполненные проверки; недоступное явно отделить от пройденного.

Игровые тесты писать только через согласованные интерфейсы. В записи результата указать выполненные проверки, наблюдаемый итог и оставшиеся ограничения.

## Финальный результат

Локальный release-архив, release notes, инструкция сборки и список проверок.

Коммит содержит ID T24, изменения и короткую запись проверки. Следующий тикет начинает работу с этого наблюдаемого результата.
