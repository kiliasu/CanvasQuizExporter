/// Interface and message text in Chinese and English.
///
/// Every entry holds both translations side by side, so a missing one is a
/// compile error rather than a blank label. Plain Dart: the parser and
/// exporter use it inside background isolates.
class Strings {
  const Strings._(this._zh);
  final bool _zh;

  static const chinese = Strings._(true);
  static const english = Strings._(false);

  /// Chinese for `zh`, English for anything else.
  static Strings forLanguage(String code) => code == 'zh' ? chinese : english;

  /// The interface language for a `system`, `zh` or `en` setting.
  static String resolve(String setting, String systemLanguage) =>
      setting == 'zh' || setting == 'en'
      ? setting
      : systemLanguage == 'zh'
      ? 'zh'
      : 'en';

  String get languageCode => _zh ? 'zh' : 'en';

  String _pick(String zh, String en) => _zh ? zh : en;
  String _count(int n, String zh, String one, String many) =>
      _zh ? '$n $zh' : '$n ${n == 1 ? one : many}';

  // Counts.
  String questions(int n) => _count(n, '道题', 'question', 'questions');
  String pages(int n) => _count(n, '个网页', 'page', 'pages');
  String formats(int n) => _count(n, '种格式', 'format', 'formats');
  String items(int n) => _count(n, '个项目', 'item', 'items');

  // Shared actions.
  String get close => _pick('关闭', 'Close');
  String get retry => _pick('重试', 'Retry');
  String get copy => _pick('复制', 'Copy');
  String get copied => _pick('已复制', 'Copied');
  String get cancel => _pick('取消', 'Cancel');
  String get cancelling => _pick('正在取消…', 'Cancelling…');

  // Header.
  String get colorScheme => _pick('配色方案', 'Color scheme');
  String schemeName(String scheme) => switch (scheme) {
    'blue' => _pick('海蓝', 'Blue'),
    'teal' => _pick('青绿', 'Teal'),
    'green' => _pick('苔绿', 'Green'),
    'rose' => _pick('玫瑰', 'Rose'),
    'amber' => _pick('琥珀', 'Amber'),
    _ => _pick('紫罗兰', 'Violet'),
  };
  String get switchToLight => _pick('切换浅色', 'Switch to light theme');
  String get switchToDark => _pick('切换深色', 'Switch to dark theme');
  String get language => _pick('语言', 'Language');
  String get systemLanguage => _pick('跟随系统', 'System default');
  String get helpTooltip => _pick('帮助 · F1', 'Help · F1');

  // Closing during an export.
  String get exportRunning => _pick('导出仍在进行', 'Export in progress');
  String get exportRunningDetail => _pick(
    '停止后将完成当前网页，再关闭窗口。已经生成的文件会保留。',
    'Stopping finishes the current page, then closes the window. Files already exported are kept.',
  );
  String get keepExporting => _pick('继续导出', 'Keep exporting');
  String get stopAndClose => _pick('停止并关闭', 'Stop and close');

  // File pickers.
  String get htmlPagesType => _pick('网页', 'HTML pages');
  String get trueTypeFontType => _pick('TrueType 字体', 'TrueType font');

  // Help.
  String get helpTitle =>
      _pick('从网页到资料，只需三步', 'From saved page to notes in three steps');
  String get helpSaveTitle => _pick('保存完整页面', 'Save the whole page');
  String get helpSaveDetail => _pick(
    '在浏览器中打开已显示题目的 Canvas 测验页，用“网页，全部”保存。HTML 与配套的 *_files 文件夹放在一起；也支持同名资源 ZIP。',
    'Open the Canvas quiz page with its questions showing and save it as "Webpage, Complete". Keep the HTML next to its *_files folder; a ZIP with the same name works too.',
  );
  String get helpCheckTitle => _pick('检查解析结果', 'Check what was read');
  String get helpCheckDetail => _pick(
    '添加 HTML 后查看题目和已有答案标记。工具不会登录、请求网络或执行网页脚本；页面没保存的题目和答案无法恢复。',
    "Add the HTML, then review the questions and answer marks. The app never logs in, goes online or runs page scripts, so anything the page didn't save can't be recovered.",
  );
  String get helpExportTitle => _pick('选择格式并导出', 'Choose formats and export');
  String get helpExportDetail => _pick(
    'TXT 适合纯文字，PDF 适合打印，Markdown 适合笔记，JSON / JSONL 适合进一步处理。重名自动编号，原文件保持不变。',
    'TXT for plain text, PDF for printing, Markdown for notes, JSON / JSONL for further processing. Clashing names get a number, and existing files stay untouched.',
  );
  String get helpPrivacy => _pick(
    '文本自动脱敏，图片不会自动脱敏。对 New Quizzes 或只保存了外壳的动态页面，可能无法识别。',
    'Text is redacted automatically; images are not. New Quizzes and dynamic pages saved without their content may not be recognized.',
  );
  String get helpShortcuts => _pick(
    'Ctrl+O 添加网页 · Ctrl+Shift+O 添加文件夹 · Ctrl+Enter 导出 · Ctrl+F 搜索 · Delete 移除选中文件',
    'Ctrl+O add pages · Ctrl+Shift+O add folder · Ctrl+Enter export · Ctrl+F search · Delete remove the selected page',
  );
  String get getStarted => _pick('开始使用', 'Get started');

  // Export log.
  String get exportLog => _pick('导出日志', 'Export log');
  String get logMayContainPaths => _pick(
    '日志可能包含本机路径。分享前请检查。',
    'The log may contain local paths. Check it before sharing.',
  );
  String get noExportsYet => _pick('尚无导出记录。', 'Nothing has been exported yet.');

  // Copy panel.
  String copyPanelSummary(int n) =>
      _pick('$n 道题 · 含题型与选项', '${questions(n)} · types and options');
  String get copyAll => _pick('复制全文', 'Copy all');
  String get copiedAll => _pick('已复制全文', 'Copied all');

  // Pages panel.
  String get pagesPanel => _pick('网页文件', 'Pages');
  String get minimizePages => _pick('最小化网页文件', 'Minimize pages');
  String get expandPages => _pick('展开网页文件', 'Expand pages');
  String get addPages => _pick('添加网页', 'Add pages');
  String get addFolder => _pick('添加文件夹', 'Add folder');
  String get dropHintEmpty => _pick(
    '支持 .html / .htm\n请保留网页配套的资源文件夹',
    "Supports .html and .htm\nKeep each page's resource folder",
  );
  String get dropHintMore => _pick(
    '把更多 HTML 或文件夹拖到这里\n重复路径会自动合并',
    'Drop more HTML files or folders here\nDuplicates are merged',
  );
  String get queueHintEmpty =>
      _pick('拖入 HTML，或添加整个文件夹。', 'Drop in HTML files, or add a whole folder.');
  String get queueHint => _pick(
    '选择文件查看解析结果。导出会处理队列中的全部网页。',
    'Select a page to review it. Export processes every page in the list.',
  );
  String get removeSelected => _pick('移除选中', 'Remove');
  String get clearAll => _pick('清空', 'Clear');
  String get entryReading => _pick('正在读取…', 'Reading…');
  String get entryUnreadable =>
      _pick('无法识别 · 不计入导出', "Unreadable · won't be exported");
  String get entryWaiting => _pick('等待解析', 'Waiting');

  // Export settings.
  String get exportSettings => _pick('导出设置', 'Export settings');
  String get minimizeSettings => _pick('最小化导出设置', 'Minimize export settings');
  String get expandSettings => _pick('展开导出设置', 'Expand export settings');
  String formatName(String format) => switch (format) {
    'txt' => _pick('纯文本', 'Plain text'),
    'pdf' => _pick('PDF 文档', 'PDF document'),
    'md' => 'Markdown',
    _ => format.toUpperCase(),
  };
  String formatDescription(String format) => switch (format) {
    'txt' => _pick('轻量、通用', 'Lightweight'),
    'pdf' => _pick('排版与打印', 'For printing'),
    'md' => _pick('笔记与知识库', 'For notes'),
    'json' => _pick('结构化数据', 'Structured data'),
    _ => _pick('每行一道题', 'One per line'),
  };
  String get fileFormats => _pick('文件格式', 'File formats');
  String get saveLocation => _pick('保存位置', 'Save to');
  String get besideSource => _pick('原文件旁', 'Next to source');
  String get customFolder => _pick('指定文件夹', 'Custom folder');
  String get outputFolder => _pick('输出目录', 'Output folder');
  String get chooseOutputFolder => _pick('选择输出目录', 'Choose output folder');
  String get saveImages => _pick('同时保存图片资源', 'Also save images');
  String get saveImagesDetail => _pick(
    '为 Markdown 等格式保存独立图片；只使用本地已保存资源。',
    'Saves images as separate files for Markdown and other formats, using only locally saved resources.',
  );
  String get filters => _pick('过滤文本', 'Filters');
  String get filtersLabel =>
      _pick('每行一条 · 句子或脱敏词', 'One per line · sentences or words');
  String get filtersHint => _pick(
    '预览、复制与导出时移除这些内容，如重复引导句、姓名、学号',
    'Removed from the preview, copies and exports, such as repeated instructions, names or student IDs',
  );
  String get repeatedSentences => _pick(
    '检测到重复出现的句子 · 点击加入过滤',
    'Repeated sentences found · click to filter',
  );
  String get moreOptions => _pick('更多选项', 'More options');
  String get moreOptionsSummary =>
      _pick('命名模板 · PDF 纸张与字体 · 脱敏词', 'File names · PDF paper and font · more');
  String get fileNaming => _pick('文件命名', 'File naming');
  String get nameTemplate => _pick('命名模板', 'Name template');
  String get nameTemplateHint => _pick(
    '重名时自动编号，不覆盖已有文件',
    'Clashing names get a number; existing files are kept',
  );
  String get pdfPaper => _pick('PDF 纸张', 'PDF paper');
  String get customPdfFont =>
      _pick('自定义 PDF 字体（可选）', 'Custom PDF font (optional)');
  String get customPdfFontHint => _pick(
    '默认 Noto Sans SC，Roboto Flex 回退',
    'Noto Sans SC by default, Roboto Flex as fallback',
  );
  String get chooseTtfFont => _pick('选择 TTF 字体', 'Choose a TTF font');
  String get diagnostics => _pick('JSON 附带诊断统计', 'Add diagnostics to JSON');
  String get diagnosticsDetail => _pick(
    '附加脱敏字段数量和 iframe 层数，便于检查解析过程。',
    'Adds redaction counts and iframe depth, to check how a page was read.',
  );
  String get openFolderWhenDone => _pick('完成后打开输出文件夹', 'Open folder when done');
  String get reduceMotion => _pick('减少动态效果', 'Reduce motion');
  String get privacyNote => _pick(
    '文本自动脱敏。图片中的个人信息请自行检查。',
    'Text is redacted automatically. Check images for personal details yourself.',
  );

  // Preview.
  String get preview => _pick('内容预览', 'Preview');
  String get reloadPage => _pick('重新读取网页', 'Reload page');
  String get statusReading => _pick('解析中', 'Reading');
  String get statusNeedsCheck => _pick('需要检查', 'Needs attention');
  String get statusWaiting => _pick('等待添加', 'No page yet');
  String get statusNoQuestions => _pick('未找到题目', 'No questions found');
  String get statusParsed => _pick('已解析', 'Parsed');
  String get readingPage => _pick('正在读取网页…', 'Reading the page…');
  String extracting(String file) => _pick(
    '正在提取题目、选项与本地图片 · $file',
    'Extracting questions, options and local images · $file',
  );
  String filtered(int n) =>
      _pick('已过滤 $n 处', n == 1 ? '1 match filtered' : '$n matches filtered');
  String get searchQuestions => _pick('搜索题目或选项', 'Search questions or options');
  String get clearSearch => _pick('清除搜索', 'Clear search');
  String get noPreviewQuestions =>
      _pick('当前网页没有可预览的题目', 'This page has no questions to preview');
  String get noMatchingQuestions => _pick('没有匹配的题目', 'No matching questions');
  String questionsShort(int n) => _pick('$n 题', questions(n));
  String questionsAllShown(int n) =>
      _pick('$n 道题 · 全部显示', '${questions(n)} · all shown');
  String get overview => _pick('总览', 'Overview');
  String get pdfPages => _pick('PDF 分页', 'PDF pages');

  // Empty and error states.
  String get emptyTitle =>
      _pick('网页里的知识，整理到手边', 'Quiz pages, turned into notes');
  String get cannotReadPage => _pick('无法读取此网页', "Couldn't read this page");
  String get emptyDetail => _pick(
    '在浏览器中完整保存测验页面，然后把 HTML 拖到这里。读取题目与答案标记，检查后再导出。',
    'Save the whole quiz page in your browser, then drop the HTML here. Review the questions and answer marks before you export.',
  );
  String get cannotReadDetail => _pick(
    '请选择另一个文件，或检查网页和资源是否保存完整。',
    'Choose another file, or check that the page and its resources were saved completely.',
  );
  String get addFirstPage => _pick('添加第一个网页', 'Add your first page');
  String get userGuide => _pick('使用指南', 'User guide');
  String get emptyShortcuts => _pick(
    'Ctrl+O 添加网页 · Ctrl+Shift+O 添加文件夹 · Ctrl+Enter 导出 · F1 指南',
    'Ctrl+O add pages · Ctrl+Shift+O add folder · Ctrl+Enter export · F1 guide',
  );

  // Question cards.
  String questionType(String type) => switch (type) {
    'multiple_choice_question' => _pick('单选题', 'Multiple choice'),
    'multiple_answers_question' => _pick('多选题', 'Multiple answers'),
    'true_false_question' => _pick('判断题', 'True / false'),
    'numerical_question' => _pick('数值题', 'Numerical'),
    'short_answer_question' => _pick('填空题', 'Fill in the blank'),
    'fill_in_multiple_blanks_question' => _pick('多空填空题', 'Fill in the blanks'),
    'multiple_dropdowns_question' => _pick('下拉选择题', 'Multiple dropdowns'),
    'matching_question' => _pick('配对题', 'Matching'),
    'essay_question' => _pick('简答题', 'Essay'),
    'file_upload_question' => _pick('文件上传题', 'File upload'),
    'text_only_question' => _pick('说明', 'Instructions'),
    _ => _pick('题目', 'Question'),
  };
  String get copyQuestion => _pick('复制题目', 'Copy question');
  String copiedQuestion(int n) => _pick('已复制第 $n 题', 'Copied question $n');
  String get selected => _pick('已选', 'Selected');
  String get correct => _pick('正确', 'Correct');
  String get answer => _pick('作答', 'Answer');
  String get answerCorrect => _pick('作答 · 正确', 'Answer · correct');
  String get correctAnswer => _pick('正确答案', 'Correct answer');
  String get onlineImage =>
      _pick('网络图片 · 无本地副本', 'Online image · no local copy');
  String get imageUnavailable => _pick('图片无法显示', "The image can't be shown");
  String localImage(String alt) => _pick('$alt · 本地资源', '$alt · local file');
  String get viewFullImage => _pick('查看完整图片', 'View full image');
  String imageViewerNote(int width, int height) => _pick(
    '$width × $height · 滚轮或手势缩放。图片中的个人信息不会自动脱敏，公开前请自行检查。',
    '$width × $height · scroll or pinch to zoom. Images are not redacted, so check them before sharing.',
  );

  // PDF preview.
  String get generatingPreview => _pick('正在生成预览…', 'Generating preview…');
  String get previewUnavailable => _pick('预览不可用', 'Preview unavailable');
  String pageOf(int page, int total, String paper) =>
      _pick('第 $page / $total 页 · $paper', 'Page $page of $total · $paper');
  String get previousPage => _pick('上一页', 'Previous page');
  String get nextPage => _pick('下一页', 'Next page');
  String get generatingPdfPreview =>
      _pick('正在生成 PDF 预览…', 'Generating PDF preview…');
  String get loading => _pick('正在加载', 'Loading');

  // Export results and footer.
  String get exportedFiles => _pick('导出记录', 'Exported files');
  String get resultsHint => _pick(
    '双击打开导出文件 · 可拖出到资源管理器',
    'Double-click to open · drag into File Explorer',
  );
  String get hideResults => _pick('收起结果', 'Hide results');
  String get noFilesCreated => _pick(
    '没有生成文件，可查看日志了解原因。',
    'No files were created. See the log for details.',
  );
  String get assetsKind => _pick('资源', 'Assets');
  String get openOutputFolder => _pick('打开输出位置', 'Open output folder');
  String get copyFilePaths => _pick('复制文件路径', 'Copy file paths');
  String copyPaths(int n) =>
      _pick('复制 $n 个路径', n == 1 ? 'Copy 1 path' : 'Copy $n paths');
  String get viewLog => _pick('查看日志', 'View log');
  String get readyToStart =>
      _pick('准备就绪 · 添加网页后即可开始', 'Ready · add pages to start');
  String get chooseAFormat =>
      _pick('请选择至少一种导出格式', 'Choose at least one export format');
  String queueSummary(int valid, int formatCount, int unreadable) => _pick(
    '$valid 个网页 · $formatCount 种格式${unreadable > 0 ? ' · $unreadable 个无法识别' : ''}',
    '${pages(valid)} · ${formats(formatCount)}${unreadable > 0 ? ' · $unreadable unreadable' : ''}',
  );
  String get exportAll => _pick('导出全部', 'Export all');
  String exportAllCount(int n) => _pick('导出全部 · $n', 'Export all · $n');
  String get moreExportOptions => _pick('更多导出方式', 'More export options');
  String exportSelected(String name) =>
      _pick('导出选中 · $name', 'Export selected · $name');
  String get exportSelectedNone =>
      _pick('导出选中 · 未选择网页', 'Export selected · no page selected');

  // Notifications.
  String cannotChoosePages(Object error) =>
      _pick('无法选择网页：$error', "Couldn't choose pages: $error");
  String cannotChooseFolder(Object error) =>
      _pick('无法选择目录：$error', "Couldn't choose a folder: $error");
  String cannotChooseFont(Object error) =>
      _pick('无法选择字体：$error', "Couldn't choose a font: $error");
  String get clipboardFailed => _pick(
    '无法写入剪贴板，请重试。',
    "Couldn't copy to the clipboard. Please try again.",
  );
  String copiedAllQuestions(int n) =>
      _pick('已复制全文 · $n 道题', 'Copied all · ${questions(n)}');
  String copiedPaths(int n) => _pick(
    '已复制 $n 个文件路径',
    n == 1 ? 'Copied 1 file path' : 'Copied $n file paths',
  );
  String get settingsNotSaved => _pick(
    '设置暂未保存，请检查配置目录权限。',
    "Settings weren't saved. Check that the settings folder is writable.",
  );
  String settingsSaveFailed(Object error) =>
      _pick('无法保存设置：$error', "Couldn't save settings: $error");
  String get noNewPages => _pick(
    '没有新增网页：支持 HTML / HTM，重复路径会自动跳过。',
    'No new pages: only HTML and HTM files are added, and duplicates are skipped.',
  );
  String cannotAddPages(Object error) =>
      _pick('无法添加网页：$error', "Couldn't add pages: $error");
  String get nothingToExport =>
      _pick('没有可导出的网页。', 'There are no pages to export.');
  String cannotOpenFolder(Object error) =>
      _pick('无法打开输出目录：$error', "Couldn't open the output folder: $error");
  String cannotOpenFile(Object error) =>
      _pick('无法打开文件：$error', "Couldn't open the file: $error");
  String cannotDragFiles(Object error) =>
      _pick('无法拖出文件：$error', "Couldn't drag the files: $error");
  String cannotCloseWindow(Object error) =>
      _pick('暂时无法关闭窗口：$error', "Couldn't close the window: $error");

  // Export progress and log.
  String exportStarting(int n, String formatList) =>
      _pick('开始导出 $n 个网页 · $formatList', 'Exporting ${pages(n)} · $formatList');
  String skipped(String name, String error) =>
      _pick('$name · 跳过：$error', '$name · skipped: $error');
  String exporting(int index, int total, String file) =>
      _pick('正在导出 $index/$total · $file', 'Exporting $index/$total · $file');
  String wrote(String path) => _pick('已写出 $path', 'Wrote $path');
  String exportFailedFor(String file, Object error) =>
      _pick('$file · 失败：$error', '$file · failed: $error');
  String get exportCancelled => _pick('已取消', 'Cancelled');
  String get exportFailed => _pick('导出失败', 'Export failed');
  String get exportPartial => _pick('部分完成', 'Partly done');
  String get exportDone => _pick('导出完成', 'Export complete');
  String exportSummary({
    required String outcome,
    required int itemCount,
    required String seconds,
    required int failures,
    required int done,
    required int total,
    required bool cancelled,
  }) => _zh
      ? '$outcome · $itemCount 个项目 · $seconds 秒${failures > 0 ? ' · $failures 项失败' : ''}${cancelled ? ' · 已处理 $done/$total' : ''}'
      : '$outcome · ${items(itemCount)} · $seconds s${failures > 0 ? ' · $failures failed' : ''}${cancelled ? ' · $done/$total processed' : ''}';
  String get stoppingAfterCurrent => _pick(
    '将在当前网页处理完成后停止，已导出的文件会保留。',
    'Stopping after the current page. Exported files are kept.',
  );

  // Reading pages.
  String get zipTooLarge =>
      _pick('配套 ZIP 超过 512 MB。', 'The companion ZIP is larger than 512 MB.');
  String get zipOverLimit => _pick(
    '配套 ZIP 超过安全读取上限。',
    'The companion ZIP is larger than it is safe to read.',
  );
  String get zipUnsafe => _pick(
    '配套 ZIP 含不安全的资源路径或过大的文件。',
    'The companion ZIP has unsafe paths or oversized files.',
  );
  String get resourceMissing => _pick(
    '网页或本地资源不存在，或位于允许目录之外。',
    'The page or a local resource is missing or outside the allowed folder.',
  );
  String get resourceTooLarge =>
      _pick('单个网页或资源超过 64 MB。', 'A page or resource is larger than 64 MB.');
  String get embeddedPageUnreadable => _pick(
    '一个内嵌网页无法读取，已继续处理其他内容。',
    "An embedded page couldn't be read; the rest was processed.",
  );
  String get noQuestionsFound => _pick(
    '网页中没有可识别的题目。请保存已显示题目的页面，并保留配套资源；登录页或动态外壳无法导出。',
    'No questions were found. Save the page while its questions are showing and keep its resources; login pages and empty dynamic pages cannot be exported.',
  );
  String imagesWithoutCopy(int n) => _pick(
    '$n 张图片没有可用的本地副本，已保留文字说明。',
    n == 1
        ? '1 image has no local copy; its description was kept.'
        : '$n images have no local copy; their descriptions were kept.',
  );

  // Checking settings and exporting.
  String get formatRequired =>
      _pick('请选择至少一种导出格式。', 'Choose at least one export format.');
  String get outputFolderRequired =>
      _pick('请选择输出文件夹。', 'Choose an output folder.');
  String get nameTemplateEmpty =>
      _pick('文件命名模板不能为空。', "The name template can't be empty.");
  String unknownNameVariable(String variable) =>
      _pick('未知命名变量：$variable', 'Unknown name variable: $variable');
  String get unbalancedBraces => _pick(
    '命名模板中的大括号必须成对出现。',
    'Braces in the name template must come in pairs.',
  );
  String get customFontMissing =>
      _pick('自定义 PDF 字体不存在。', "The custom PDF font doesn't exist.");
  String get fontTooLarge => _pick('字体文件过大。', 'The font file is too large.');
  String get fontUnreadable => _pick(
    '无法读取字体，请选择有效的 TTF 字体。',
    "Couldn't read the font. Choose a valid TTF font.",
  );
  String get assetsFolderAppeared => _pick(
    '资源目录在导出期间被创建，请重试。',
    'The assets folder appeared during export. Please try again.',
  );
  String saveFailed(String file, Object error) =>
      _pick('$file · 保存失败：$error', '$file · could not be saved: $error');
}
