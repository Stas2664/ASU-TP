const fs = require('fs');
const path = require('path');

console.log('Генерация PNG/PDF из SVG...');

const svgPath = path.join(__dirname, 'er_diagram.svg');
const htmlPath = path.join(__dirname, 'export_diagram.html');

if (!fs.existsSync(svgPath)) {
    console.error('❌ Файл er_diagram.svg не найден');
    process.exit(1);
}

console.log(`
✅ SVG создан: diagrams/er_diagram.svg
✅ HTML создан: diagrams/export_diagram.html

📋 Для получения PNG/PDF:
   
   ВАРИАНТ 1 (Автоматический - через браузер):
   1. Откройте diagrams/export_diagram.html в Chrome
   2. Нажмите "Скачать PNG" → файл сохранится автоматически
   3. Нажмите "Печать" → Сохранить как PDF → diagrams/er_diagram.pdf
   
   ВАРИАНТ 2 (Через онлайн-сервис):
   1. Откройте https://cloudconvert.com/svg-to-png
   2. Загрузите diagrams/er_diagram.svg
   3. Скачайте как PNG и PDF
   
   ВАРИАНТ 3 (Через dbdiagram.io):
   1. Откройте https://dbdiagram.io/d
   2. Скопируйте содержимое docs/acceptance/er_diagram.dbml
   3. Export → PNG и Export → PDF

⚠️  После получения файлов переместите их:
   - er_diagram.png → diagrams/er_diagram.png
   - er_diagram.pdf → diagrams/er_diagram.pdf
`);

// Создаем placeholder README
const readmePath = path.join(__dirname, 'README.md');
const readmeContent = `# Диаграммы БД АСУ ТП

## Файлы

- \`er_diagram.svg\` - ER-диаграмма в векторном формате (готово ✅)
- \`er_diagram.png\` - ER-диаграмма PNG (нужно сгенерировать)
- \`er_diagram.pdf\` - ER-диаграмма PDF (нужно сгенерировать)
- \`export_diagram.html\` - Инструмент экспорта (откройте в браузере)

## Как получить PNG/PDF

### Способ 1: Через браузер (рекомендуется)
1. Откройте \`export_diagram.html\` в Chrome
2. Нажмите кнопку "Скачать PNG"
3. Для PDF: Ctrl+P → Сохранить как PDF

### Способ 2: Через dbdiagram.io
1. Откройте https://dbdiagram.io/d
2. Import → вставьте содержимое \`docs/acceptance/er_diagram.dbml\`
3. Export → PNG и PDF

### Способ 3: Онлайн-конвертер
https://cloudconvert.com/svg-to-png - загрузите \`er_diagram.svg\`

---

Конфиденциально. АО «НИКИЭТ».
`;

fs.writeFileSync(readmePath, readmeContent, 'utf8');
console.log('✅ README.md обновлен в diagrams/');

