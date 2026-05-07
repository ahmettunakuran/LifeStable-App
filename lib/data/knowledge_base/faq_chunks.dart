/// Each entry maps to one doc_embeddings document.
/// Fields: title_type (unique doc ID), content (embedded text),
/// doc_type, source_key, indexes (keyword pre-filter tokens).
///
/// Content is bilingual (EN/TR) so semantic search works for both languages.

const List<Map<String, dynamic>> kFaqChunks = [
  // ── DOMAINS ──────────────────────────────────────────────────────────────

  {
    'title_type': 'domain_create',
    'doc_type': 'faq',
    'source_key': 'domain_management',
    'content':
        'How do I create a new domain? Tap the + button on the Home Dashboard, '
        'enter a name, pick an icon and color, then tap Save. Domains are '
        'personal workspaces that group your tasks and notes (e.g. "University", '
        '"Part-time Job", "Personal"). '
        // TR
        'Yeni bir alan nasıl oluşturulur? Ana Ekranda sağ alttaki + düğmesine '
        'basın, bir isim girin, ikon ve renk seçin, ardından Kaydet\'e dokunun. '
        'Alanlar görevlerinizi ve notlarınızı gruplandıran kişisel çalışma '
        'alanlarıdır (örn. "Üniversite", "Yarı Zamanlı İş", "Kişisel").',
    'indexes': ['domain', 'create', 'add', 'workspace', 'new', 'how',
                'alan', 'oluştur', 'ekle', 'nasıl'],
  },
  {
    'title_type': 'domain_edit',
    'doc_type': 'faq',
    'source_key': 'domain_management',
    'content':
        'How do I edit or rename a domain? Long-press the domain card on the '
        'Dashboard, then tap Edit. You can change the name, icon, color, and '
        'description. Team mirror domains cannot be edited directly. '
        // TR
        'Bir alan nasıl düzenlenir veya yeniden adlandırılır? Alan kartına '
        'uzun basın ve Düzenle\'yi seçin. İsim, ikon, renk ve açıklamayı '
        'değiştirebilirsiniz. Takım ayna alanları doğrudan düzenlenemez.',
    'indexes': ['domain', 'edit', 'rename', 'update', 'change', 'how',
                'alan', 'düzenle', 'yeniden', 'adlandır', 'nasıl'],
  },
  {
    'title_type': 'domain_delete',
    'doc_type': 'faq',
    'source_key': 'domain_management',
    'content':
        'How do I delete a domain? Long-press the domain card, tap Delete, and '
        'confirm. Deleting a domain removes all tasks and notes inside it. '
        'Team mirror domains are removed automatically when you leave the team. '
        // TR
        'Bir alan nasıl silinir? Alan kartına uzun basın ve Sil\'e dokunun, '
        'ardından onaylayın. Bir alanı silmek içindeki tüm görevleri ve notları '
        'da kaldırır. Takım ayna alanları takımdan ayrıldığınızda otomatik silinir.',
    'indexes': ['domain', 'delete', 'remove', 'how',
                'alan', 'sil', 'kaldır', 'nasıl'],
  },
  {
    'title_type': 'domain_team_mirror',
    'doc_type': 'faq',
    'source_key': 'domain_management',
    'content':
        'What is a team mirror domain? When you join or create a team, '
        'LifeStable automatically creates a domain named after the team so team '
        'tasks and calendar events appear in your personal view. This mirror '
        'domain syncs with the team board in real time. '
        // TR
        'Takım ayna alanı nedir? Bir takıma katıldığınızda veya oluşturduğunuzda '
        'LifeStable otomatik olarak takımın adını taşıyan bir alan oluşturur; '
        'böylece takım görevleri ve takvim etkinlikleri kişisel görünümünüzde '
        'belirir. Bu alan takım panosuyla gerçek zamanlı senkronize olur.',
    'indexes': ['domain', 'team', 'mirror', 'sync', 'what',
                'alan', 'takım', 'ayna', 'senkron', 'nedir'],
  },

  // ── TASKS ─────────────────────────────────────────────────────────────────

  {
    'title_type': 'task_create',
    'doc_type': 'faq',
    'source_key': 'task_creation',
    'content':
        'How do I create a task? Open a domain, tap the + button, fill in the '
        'title, optional description, priority, and due date, then tap Save. '
        'You can also tell the AI assistant "Add task [title] by [date]". '
        'You can find the domain list on the Home Dashboard via the Sidebar menu. '
        // TR
        'Görev nasıl oluşturulur? Bir alanı açın, + düğmesine dokunun, başlığı, '
        'açıklamayı, önceliği ve bitiş tarihini doldurup Kaydet\'e basın. '
        'Yapay zeka asistanına "Görev ekle [başlık] [tarih]" de de ekleyebilirsiniz.',
    'indexes': ['task', 'create', 'add', 'new', 'how',
                'görev', 'oluştur', 'ekle', 'nasıl'],
  },
  {
    'title_type': 'task_priority',
    'doc_type': 'faq',
    'source_key': 'task_creation',
    'content':
        'How do I set task priority? When creating or editing a task, tap the '
        'Priority field and choose Low, Medium, or High. High-priority tasks '
        'appear highlighted in the Kanban board and first in the Dashboard summary. '
        // TR
        'Görev önceliği nasıl ayarlanır? Görev oluştururken veya düzenlerken '
        'Öncelik alanına dokunun ve Düşük, Orta veya Yüksek seçin. Yüksek '
        'öncelikli görevler Kanban panosunda vurgulanır.',
    'indexes': ['task', 'priority', 'high', 'medium', 'low', 'set', 'how',
                'görev', 'öncelik', 'ayarla', 'nasıl'],
  },
  {
    'title_type': 'task_due_date',
    'doc_type': 'faq',
    'source_key': 'task_creation',
    'content':
        'How do I set a due date on a task? Tap the Due Date field in the task '
        'form and pick a date from the calendar picker. Tasks with due dates '
        'appear in your Calendar view and in the Dashboard "Close Deadlines" card. '
        // TR
        'Görev için bitiş tarihi nasıl belirlenir? Görev formunda Bitiş Tarihi '
        'alanına dokunun ve tarih seçiciden bir tarih seçin. Bitiş tarihli '
        'görevler Takvim\'inizde ve Ana Ekran "Yaklaşan Son Tarihler" kartında görünür.',
    'indexes': ['task', 'due', 'date', 'deadline', 'set', 'how',
                'görev', 'bitiş', 'tarih', 'son', 'nasıl'],
  },
  {
    'title_type': 'task_kanban',
    'doc_type': 'faq',
    'source_key': 'task_creation',
    'content':
        'How do I move a task between Kanban columns? Open the Kanban board for '
        'a domain and drag the task card from "To Do" to "In Progress" or "Done". '
        'For team tasks, the board updates in real time for all members. '
        'You can access the Kanban board from the Domain Dashboard. '
        // TR
        'Kanban sütunları arasında görev nasıl taşınır? Bir alanın Kanban '
        'panosunu açın ve görev kartını "Yapılacak"tan "Devam Ediyor" veya '
        '"Tamamlandı" sütununa sürükleyin. Takım görevleri için pano tüm '
        'üyelerde gerçek zamanlı güncellenir.',
    'indexes': ['task', 'kanban', 'move', 'status', 'column', 'drag', 'how',
                'görev', 'taşı', 'sütun', 'nasıl'],
  },
  {
    'title_type': 'task_assign',
    'doc_type': 'faq',
    'source_key': 'task_creation',
    'content':
        'How do I assign a task to a team member? On a team Kanban board, open '
        'a task, tap Assign, and choose a member from the list. The assigned '
        'member receives a push notification and the task appears in their list. '
        // TR
        'Bir görevi takım üyesine nasıl atarım? Takım Kanban panosunda bir '
        'görevi açın, Ata\'ya dokunun ve listeden bir üye seçin. Atanan üye '
        'bildirim alır ve görev onun listesinde görünür.',
    'indexes': ['task', 'assign', 'team', 'member', 'how',
                'görev', 'ata', 'takım', 'üye', 'nasıl'],
  },
  {
    'title_type': 'task_edit_delete',
    'doc_type': 'faq',
    'source_key': 'task_creation',
    'content':
        'How do I edit or delete a task? Tap a task card to open its details, '
        'then tap the Edit icon to change title, description, priority, or due '
        'date. To delete, tap the trash icon and confirm. The AI assistant can '
        'also delete tasks: say "Delete task [title]". '
        // TR
        'Görev nasıl düzenlenir veya silinir? Görev kartına dokunarak ayrıntıları '
        'açın, ardından Düzenle simgesine dokunun. Silmek için çöp kutusu '
        'simgesine dokunup onaylayın. Yapay zeka asistanına "Görev sil [başlık]" '
        'de de silebilirsiniz.',
    'indexes': ['task', 'edit', 'delete', 'update', 'remove', 'how',
                'görev', 'düzenle', 'sil', 'nasıl'],
  },

  // ── HABITS ───────────────────────────────────────────────────────────────

  {
    'title_type': 'habit_create',
    'doc_type': 'faq',
    'source_key': 'habit_tracker',
    'content':
        'How do I create a habit? Go to the Habit Tracker tab via the Sidebar '
        'menu, tap +, enter a habit name, set the frequency, and optionally set '
        'a reminder time. Tap Save to start tracking. '
        // TR
        'Alışkanlık nasıl oluşturulur? Kenar çubuğu menüsünden Alışkanlık '
        'Takipçisi sekmesine gidin, + simgesine dokunun, bir ad girin, sıklığı '
        'ayarlayın ve isteğe bağlı olarak hatırlatma saati belirleyin, ardından Kaydet\'e basın.',
    'indexes': ['habit', 'create', 'add', 'new', 'tracker', 'how',
                'alışkanlık', 'oluştur', 'ekle', 'nasıl'],
  },
  {
    'title_type': 'habit_streak',
    'doc_type': 'faq',
    'source_key': 'habit_tracker_streak',
    'content':
        'How does the habit streak work? Each consecutive day you mark a habit '
        'complete, your streak counter increases by one. Missing a day resets '
        'the streak to zero. Your longest streak earns you XP points. '
        // TR
        'Alışkanlık serisi nasıl çalışır? Her ardışık günde alışkanlığı '
        'tamamlandı işaretlerseniz seri sayacınız bir artar. Bir günü kaçırmanız '
        'seriyi sıfırlar. En uzun seriniz XP puanı kazandırır.',
    'indexes': ['habit', 'streak', 'consecutive', 'days', 'how', 'what',
                'alışkanlık', 'seri', 'gün', 'nasıl', 'nedir'],
  },
  {
    'title_type': 'habit_complete',
    'doc_type': 'faq',
    'source_key': 'habit_tracker',
    'content':
        'How do I mark a habit as complete? In the Habit Tracker, tap the circle '
        'next to the habit name for today. It turns filled to show completion. '
        'You can only mark a habit complete once per day. '
        // TR
        'Alışkanlık nasıl tamamlandı işaretlenir? Alışkanlık Takipçisinde '
        'alışkanlık adının yanındaki daireye dokunun. Dolu olarak görünmesi '
        'tamamlandığını gösterir. Günde yalnızca bir kez işaretlenebilir.',
    'indexes': ['habit', 'complete', 'mark', 'check', 'done', 'how',
                'alışkanlık', 'tamamla', 'işaretle', 'nasıl'],
  },
  {
    'title_type': 'habit_pause',
    'doc_type': 'faq',
    'source_key': 'habit_tracker',
    'content':
        'How do I pause or resume a habit? Swipe left on a habit card and tap '
        'Pause. While paused, the habit does not appear in your daily checklist '
        'and missing days do not break your streak. Tap Resume to reactivate. '
        // TR
        'Alışkanlık nasıl duraklatılır veya devam ettirilir? Alışkanlık kartını '
        'sola kaydırıp Duraklat\'a dokunun. Duraklatıldığında günlük listenizde '
        'görünmez ve kaçırılan günler seriyi bozmaz. Devam Et\'e dokunarak '
        'yeniden aktif hale getirin.',
    'indexes': ['habit', 'pause', 'resume', 'stop', 'skip', 'how',
                'alışkanlık', 'duraklat', 'devam', 'nasıl'],
  },
  {
    'title_type': 'habit_health_guardrail',
    'doc_type': 'faq',
    'source_key': 'habit_tracker',
    'content':
        'What are habit health guardrails? LifeStable monitors how many habits '
        'you have active. If you add too many at once, the app suggests focusing '
        'on fewer to avoid burnout. You can dismiss the warning and keep all. '
        // TR
        'Alışkanlık sağlık koruyucuları nedir? LifeStable aktif alışkanlık '
        'sayınızı izler. Çok fazla eklerseniz uygulama daha azına odaklanmanızı '
        'önerir. Uyarıyı kapatıp tümünü saklayabilirsiniz.',
    'indexes': ['habit', 'health', 'guardrail', 'limit', 'burnout', 'what',
                'alışkanlık', 'sağlık', 'koruyucu', 'nedir'],
  },

  // ── TEAMS ────────────────────────────────────────────────────────────────

  {
    'title_type': 'team_create',
    'doc_type': 'faq',
    'source_key': 'team_management',
    'content':
        'How do I create a team? Go to Teams via the Sidebar menu, tap Create '
        'Team, enter a name, objective, and color. You become the team Owner. '
        'A unique invite code is generated automatically. '
        // TR
        'Takım nasıl oluşturulur? Kenar çubuğu menüsünden Takımlar\'a gidin, '
        'Takım Oluştur\'a dokunun, isim, amaç ve renk girin. Takım Sahibi '
        'olursunuz. Benzersiz bir davet kodu otomatik oluşturulur.',
    'indexes': ['team', 'create', 'new', 'start', 'how',
                'takım', 'oluştur', 'başlat', 'nasıl'],
  },
  {
    'title_type': 'team_join',
    'doc_type': 'faq',
    'source_key': 'team_management',
    'content':
        'How do I join a team? Go to Teams and tap Join with Code. Enter the '
        '6-character invite code shared by the team owner. Once joined, the '
        "team's Kanban board and shared tasks become visible in your workspace. "
        // TR
        'Takıma nasıl katılırım? Takımlar\'a gidin ve Kodla Katıl\'a dokunun. '
        'Takım sahibinin paylaştığı 6 karakterli davet kodunu girin. '
        'Katıldıktan sonra takımın Kanban panosu ve paylaşılan görevler '
        'çalışma alanınızda görünür.',
    'indexes': ['team', 'join', 'invite', 'code', 'how',
                'takım', 'katıl', 'davet', 'kod', 'nasıl'],
  },
  {
    'title_type': 'team_invite_code',
    'doc_type': 'faq',
    'source_key': 'team_management',
    'content':
        'How do I share the team invite code? Open Team Detail, tap the copy '
        'icon next to the invite code, then share it via any messaging app. '
        'Owners and admins can regenerate the code if compromised. '
        // TR
        'Takım davet kodunu nasıl paylaşırım? Takım Detayı\'nı açın, davet '
        'kodunun yanındaki kopyala simgesine dokunun ve herhangi bir mesajlaşma '
        'uygulaması ile paylaşın. Sahipler ve yöneticiler kodu yenileyebilir.',
    'indexes': ['team', 'invite', 'code', 'share', 'how',
                'takım', 'davet', 'kod', 'paylaş', 'nasıl'],
  },
  {
    'title_type': 'team_roles',
    'doc_type': 'faq',
    'source_key': 'team_management',
    'content':
        'What are team roles? There are three roles: Owner (full control, can '
        'delete team), Admin (can manage members and regenerate invite codes), '
        'and Member (can create and update tasks on the team board). '
        // TR
        'Takım rolleri nelerdir? Üç rol vardır: Sahip (tam kontrol, takımı '
        'silebilir), Yönetici (üyeleri yönetebilir, davet kodunu yenileyebilir), '
        'Üye (takım panosunda görev oluşturabilir ve güncelleyebilir).',
    'indexes': ['team', 'role', 'owner', 'admin', 'member', 'what',
                'takım', 'rol', 'sahip', 'yönetici', 'üye', 'nedir'],
  },
  {
    'title_type': 'team_leave',
    'doc_type': 'faq',
    'source_key': 'team_management',
    'content':
        'How do I leave a team? Go to Team Detail, scroll to the bottom, and '
        'tap Leave Team. If you are the only owner, promote another member first. '
        'Leaving removes the team mirror domain from your workspace. '
        // TR
        'Takımdan nasıl ayrılırım? Takım Detayı\'na gidin, aşağı kaydırın ve '
        'Takımdan Ayrıl\'a dokunun. Tek sahibinizse önce başka birini sahip '
        'yapmalısınız. Ayrılmak takım ayna alanını çalışma alanınızdan kaldırır.',
    'indexes': ['team', 'leave', 'exit', 'how',
                'takım', 'ayrıl', 'çık', 'nasıl'],
  },
  {
    'title_type': 'team_kanban',
    'doc_type': 'faq',
    'source_key': 'team_management',
    'content':
        'How does the team Kanban board work? The team Kanban board shows all '
        'tasks shared across members in To Do, In Progress, and Done columns. '
        'Any member can move tasks; changes sync in real time for all members. '
        // TR
        'Takım Kanban panosu nasıl çalışır? Paylaşılan tüm görevleri Yapılacak, '
        'Devam Ediyor ve Tamamlandı sütunlarında gösterir. Her üye görevleri '
        'taşıyabilir; değişiklikler anında senkronize olur.',
    'indexes': ['team', 'kanban', 'board', 'shared', 'how', 'what',
                'takım', 'pano', 'paylaşılan', 'nasıl', 'nedir'],
  },

  // ── AI ASSISTANT ─────────────────────────────────────────────────────────

  {
    'title_type': 'ai_what_can_do',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'What can the AI assistant do? The AI assistant can create, edit, and '
        'delete tasks and calendar events using natural language. It can also '
        'find free time gaps in your schedule. You can access it from the '
        'Sidebar menu under "AI Bot". '
        // TR
        'Yapay zeka asistanı ne yapabilir? Görevler ve takvim etkinlikleri '
        'oluşturabilir, düzenleyebilir ve silebilir. Takviminizde boş zaman '
        'aralıkları da bulabilir. Kenar çubuğu menüsünden "AI Bot" ile erişebilirsiniz.',
    'indexes': ['ai', 'assistant', 'can', 'do', 'what', 'help',
                'yapay', 'zeka', 'asistan', 'yapabilir', 'nedir', 'neler'],
  },
  {
    'title_type': 'ai_text_command',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'How do I use text commands with the AI? Open the AI Assistant from the '
        'Sidebar menu and type a command such as "Add task Study for exam by '
        'Friday" or "Delete all done tasks". The AI understands English and '
        'Turkish naturally. '
        // TR
        'Yapay zeka ile metin komutları nasıl kullanılır? Kenar çubuğu menüsünden '
        'AI Asistan\'ı açın ve "Sınava çalış görevi ekle Cumaya kadar" gibi '
        'bir komut yazın. Yapay zeka Türkçe ve İngilizce komutları anlar.',
    'indexes': ['ai', 'text', 'command', 'type', 'message', 'how',
                'yapay', 'zeka', 'komut', 'yaz', 'nasıl'],
  },
  {
    'title_type': 'ai_voice_input',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'How do I use voice input with the AI? Tap the microphone icon in the '
        'assistant chat. Speak your command and the app converts it to text. '
        'Make sure to grant microphone permission when prompted. '
        // TR
        'Yapay zeka ile sesli giriş nasıl kullanılır? Asistan sohbetindeki '
        'mikrofon simgesine dokunun. Komutunuzu söyleyin, uygulama metne '
        'çevirir. İstendiğinde mikrofon iznini vermeyi unutmayın.',
    'indexes': ['ai', 'voice', 'microphone', 'speak', 'how',
                'yapay', 'zeka', 'ses', 'mikrofon', 'nasıl'],
  },
  {
    'title_type': 'ai_create_task',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'How do I create a task using the AI? Say or type "Create task [title] '
        'in [domain] by [date] with [priority] priority". Example: "Create task '
        'Submit report in University by Monday with high priority". '
        // TR
        'Yapay zekayla görev nasıl oluşturulur? "Görev oluştur [başlık] '
        '[alanda] [tarihe] kadar [öncelik] öncelikle" yazın. '
        'Örnek: "Üniversite alanında Pazartesiye kadar yüksek öncelikli rapor hazırla görevi oluştur".',
    'indexes': ['ai', 'create', 'task', 'how',
                'yapay', 'zeka', 'görev', 'oluştur', 'nasıl'],
  },
  {
    'title_type': 'ai_calendar_event',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'How do I add a calendar event with the AI? Type "Add event [title] on '
        '[date] from [time] to [time]". Example: "Add event Team meeting on '
        'Thursday from 3pm to 4pm". The AI creates the event and opens Calendar. '
        // TR
        'Yapay zekayla takvim etkinliği nasıl eklenir? "Etkinlik ekle [başlık] '
        '[tarihinde] [saatten] [saate]" yazın. Örnek: "Perşembe saat 15:00-16:00 '
        'arası takım toplantısı ekle".',
    'indexes': ['ai', 'calendar', 'event', 'add', 'create', 'how',
                'yapay', 'zeka', 'takvim', 'etkinlik', 'ekle', 'nasıl'],
  },
  {
    'title_type': 'ai_find_gap',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'How do I find free time in my schedule? Ask the AI "Find me a free '
        'slot this week for 2 hours of studying". The assistant scans your '
        'existing calendar events and suggests available time gaps. '
        // TR
        'Takvimimde boş zaman nasıl bulunur? Yapay zekaya "Bu hafta 2 saatlik '
        'boş bir zaman dilimi bul" deyin. Asistan mevcut etkinlikleri tarayarak '
        'uygun aralıklar önerir.',
    'indexes': ['ai', 'free', 'time', 'gap', 'schedule', 'find', 'how',
                'yapay', 'zeka', 'boş', 'zaman', 'bul', 'nasıl'],
  },
  {
    'title_type': 'ai_image_upload',
    'doc_type': 'faq',
    'source_key': 'ai_assistant',
    'content':
        'Can I upload an image of my schedule to the AI? Yes — tap the image '
        'icon in the chat bar and select a photo of a timetable. The app uses '
        'OCR to read the text and imports the events automatically. '
        // TR
        'Ders programımın fotoğrafını yapay zekaya yükleyebilir miyim? Evet — '
        'sohbet çubuğundaki resim simgesine dokunun ve ders programınızın '
        'fotoğrafını seçin. Uygulama metni okuyarak etkinlikleri otomatik ekler.',
    'indexes': ['ai', 'image', 'upload', 'photo', 'schedule', 'ocr', 'how',
                'yapay', 'zeka', 'resim', 'fotoğraf', 'yükle', 'nasıl'],
  },

  // ── CALENDAR ─────────────────────────────────────────────────────────────

  {
    'title_type': 'calendar_create_event',
    'doc_type': 'faq',
    'source_key': 'calendar',
    'content':
        'How do I manually create a calendar event? Open the Calendar tab via '
        'the Sidebar menu, tap a date, then tap the + button. Fill in the title, '
        'start and end time, and event type. Tap Save to add it. '
        // TR
        'Takvim etkinliği nasıl elle oluşturulur? Kenar çubuğu menüsünden '
        'Takvim sekmesini açın, bir tarihe dokunun ve + düğmesine basın. '
        'Başlık, başlangıç-bitiş saati ve etkinlik türünü doldurup Kaydet\'e dokunun.',
    'indexes': ['calendar', 'event', 'create', 'add', 'how',
                'takvim', 'etkinlik', 'oluştur', 'ekle', 'nasıl'],
  },
  {
    'title_type': 'calendar_google_sync',
    'doc_type': 'faq',
    'source_key': 'calendar',
    'content':
        'How do I sync with Google Calendar? Go to Settings → Calendar Sync and '
        'tap Connect. Find Settings in the Sidebar menu at the bottom. After '
        'authorizing, your Google Calendar events appear in LifeStable. '
        // TR
        'Google Takvim ile nasıl senkronize ederim? Kenar çubuğu menüsünün '
        'altındaki Ayarlar\'a gidin ve Takvim Senkronizasyonu bölümünden '
        'Bağlan\'a dokunun. Yetkilendirdikten sonra Google etkinlikleri '
        'LifeStable\'da görünür.',
    'indexes': ['calendar', 'google', 'sync', 'connect', 'import', 'how',
                'takvim', 'google', 'senkron', 'bağlan', 'nasıl'],
  },
  {
    'title_type': 'calendar_ocr_import',
    'doc_type': 'faq',
    'source_key': 'calendar',
    'content':
        'How do I import a class schedule using a photo? In the AI Assistant '
        'chat, tap the image icon and take or choose a photo of your timetable. '
        'The app reads the text with OCR and shows a preview before adding events. '
        // TR
        'Ders programını fotoğrafla nasıl içe aktarırım? Yapay Zeka Asistanı '
        'sohbetinde resim simgesine dokunun ve ders programınızın fotoğrafını '
        'seçin. Uygulama metni okur ve etkinlikleri eklemeden önce önizleme gösterir.',
    'indexes': ['calendar', 'ocr', 'import', 'photo', 'class', 'schedule', 'how',
                'takvim', 'içe', 'aktar', 'fotoğraf', 'ders', 'nasıl'],
  },
  {
    'title_type': 'calendar_team_events',
    'doc_type': 'faq',
    'source_key': 'calendar',
    'content':
        'How do team task deadlines appear in my calendar? Whenever a team '
        'member sets a due date on a shared task, LifeStable automatically '
        'creates a calendar event for every team member. '
        // TR
        'Takım görevlerinin son tarihleri takvimde nasıl görünür? Bir takım '
        'üyesi paylaşılan göreve bitiş tarihi belirlediğinde LifeStable '
        'otomatik olarak tüm üyeler için bir takvim etkinliği oluşturur.',
    'indexes': ['calendar', 'team', 'task', 'deadline', 'sync', 'what',
                'takvim', 'takım', 'görev', 'son', 'tarih', 'nedir'],
  },

  // ── LOCATION REMINDERS ───────────────────────────────────────────────────

  {
    'title_type': 'location_create_alert',
    'doc_type': 'faq',
    'source_key': 'location_alerts',
    'content':
        'How do I create a location reminder? Open the Alerts tab via the '
        'Sidebar menu under "Add Location", tap +, search for or pin a location '
        'on the map, write your reminder message, and choose Arrival, Departure, '
        'or both. Tap Save to activate the geofence. '
        // TR
        'Konum hatırlatıcısı nasıl oluşturulur? Kenar çubuğu menüsündeki '
        '"Konum Ekle" sekmesini açın, + simgesine dokunun, haritada bir konum '
        'arayın veya sabitleyip mesajınızı yazın, Varış veya Ayrılış seçeneğini '
        'belirleyin ve Kaydet\'e dokunun.',
    'indexes': ['location', 'alert', 'reminder', 'geofence', 'create', 'how',
                'konum', 'hatırlatıcı', 'oluştur', 'nasıl'],
  },
  {
    'title_type': 'location_time_constraint',
    'doc_type': 'faq',
    'source_key': 'location_alerts',
    'content':
        'Can I limit when location reminders fire? Yes — when creating an alert '
        'you can set a "Do not remind after" time so the reminder never fires '
        'late at night even if you pass the location. '
        // TR
        'Konum hatırlatıcılarının çalışma saatlerini sınırlayabilir miyim? '
        'Evet — uyarı oluştururken "Şu saatten sonra hatırlatma" seçeneği '
        'ayarlayabilirsiniz; böylece geç saatlerde konumun yakınından geçseniz '
        'bile bildirim gelmez.',
    'indexes': ['location', 'alert', 'time', 'limit', 'quiet', 'how',
                'konum', 'saat', 'sınır', 'nasıl'],
  },
  {
    'title_type': 'location_arrival_departure',
    'doc_type': 'faq',
    'source_key': 'location_alerts',
    'content':
        'What is the difference between arrival and departure triggers? Arrival '
        'triggers fire when you enter the geofenced area. Departure triggers '
        'fire when you leave. You can enable both on a single alert. '
        // TR
        'Varış ve ayrılış tetikleyicileri arasındaki fark nedir? Varış '
        'tetikleyicisi coğrafi çit alanına girdiğinizde, ayrılış tetikleyicisi '
        'çıktığınızda çalışır. Tek bir uyarıda her ikisini de etkinleştirebilirsiniz.',
    'indexes': ['location', 'arrival', 'departure', 'trigger', 'what', 'difference',
                'konum', 'varış', 'ayrılış', 'fark', 'nedir'],
  },
  {
    'title_type': 'location_permissions',
    'doc_type': 'faq',
    'source_key': 'location_alerts',
    'content':
        'Why do location reminders need "Always On" permission? Geofencing must '
        'detect your location even when the app is closed. On iOS go to Settings '
        '→ LifeStable → Location → Always. On Android grant "Allow all the time". '
        // TR
        'Konum hatırlatıcıları neden "Her Zaman" iznine ihtiyaç duyar? Coğrafi '
        'çit, uygulama kapalıyken de konumunuzu algılamalıdır. iOS\'ta Ayarlar '
        '→ LifeStable → Konum → Her Zaman. Android\'de "Her zaman izin ver"i seçin.',
    'indexes': ['location', 'permission', 'always', 'background', 'why',
                'konum', 'izin', 'her', 'zaman', 'neden'],
  },

  // ── DASHBOARD ────────────────────────────────────────────────────────────

  {
    'title_type': 'dashboard_overview',
    'doc_type': 'faq',
    'source_key': 'dashboard',
    'content':
        'What does the Dashboard show? The Home Dashboard displays all your '
        'domains as cards. Tapping a domain opens its task Kanban board. The '
        'top shows a quick summary of today\'s tasks and upcoming deadlines. '
        'Access the Dashboard from the Sidebar home icon or the Home button. '
        // TR
        'Ana Ekran ne gösterir? Tüm alanlarınızı kart olarak görüntüler. Bir '
        'alana dokunmak Kanban panosunu açar. Üstte bugünkü görevler ve '
        'yaklaşan son tarihler özetlenir. Kenar çubuğundaki ev simgesiyle erişebilirsiniz.',
    'indexes': ['dashboard', 'home', 'overview', 'what', 'show',
                'ana', 'ekran', 'anasayfa', 'nedir', 'gösterir'],
  },
  {
    'title_type': 'dashboard_deadlines',
    'doc_type': 'faq',
    'source_key': 'dashboard',
    'content':
        'What is the Close Deadlines card? The Close Deadlines card on the '
        'Dashboard highlights tasks due within the next 72 hours across all '
        'domains. Tap any item to jump directly to that task\'s detail page. '
        // TR
        'Yaklaşan Son Tarihler kartı nedir? Ana Ekrandaki bu kart tüm alanlarda '
        'önümüzdeki 72 saat içinde bitiş tarihi olan görevleri vurgular. '
        'Herhangi bir öğeye dokunarak doğrudan görev detayına gidebilirsiniz.',
    'indexes': ['dashboard', 'deadline', 'close', 'upcoming', 'what',
                'son', 'tarih', 'yaklaşan', 'nedir'],
  },

  // ── NOTIFICATIONS ────────────────────────────────────────────────────────

  {
    'title_type': 'notifications_manage',
    'doc_type': 'faq',
    'source_key': 'notifications',
    'content':
        'How do I manage notification preferences? Go to Settings in the Sidebar '
        'menu to toggle push notifications for task reminders, habit reminders, '
        'team updates, and location alerts independently. '
        // TR
        'Bildirim tercihlerini nasıl yönetirim? Kenar çubuğu menüsündeki '
        'Ayarlar\'a gidin. Görev hatırlatıcıları, alışkanlık hatırlatıcıları, '
        'takım güncellemeleri ve konum uyarıları için bildirimleri ayrı ayrı '
        'açıp kapatabilirsiniz.',
    'indexes': ['notification', 'manage', 'settings', 'preference', 'how',
                'bildirim', 'yönet', 'ayar', 'tercih', 'nasıl'],
  },
  {
    'title_type': 'notifications_mute',
    'doc_type': 'faq',
    'source_key': 'notifications',
    'content':
        'How do I mute reminders for a specific time? Set a "Do Not Disturb" '
        'window in Settings → Notifications → Quiet Hours. Enter a start and '
        'end time; all app notifications will be silenced during that window. '
        // TR
        'Belirli bir süre için hatırlatıcıları nasıl sustururum? Ayarlar → '
        'Bildirimler → Sessiz Saatler bölümünden başlangıç ve bitiş saatini '
        'girin; uygulama bildirimleri o zaman diliminde sessize alınır.',
    'indexes': ['notification', 'mute', 'quiet', 'silence', 'dnd', 'how',
                'bildirim', 'sustur', 'sessiz', 'saat', 'nasıl'],
  },

  // ── OFFLINE MODE ─────────────────────────────────────────────────────────

  {
    'title_type': 'offline_behavior',
    'doc_type': 'faq',
    'source_key': 'offline_mode',
    'content':
        'How does LifeStable work offline? Tasks and domains are cached locally '
        'so you can view and create them without internet. Changes sync '
        'automatically when the connection is restored. Calendar events and team '
        'data require a connection to load the latest updates. '
        // TR
        'LifeStable çevrimdışı nasıl çalışır? Görevler ve alanlar yerel olarak '
        'önbelleğe alınır; internet olmadan görüntüleyip oluşturabilirsiniz. '
        'Değişiklikler bağlantı yeniden kurulduğunda otomatik senkronize olur. '
        'Takvim etkinlikleri ve takım verileri için bağlantı gereklidir.',
    'indexes': ['offline', 'no', 'internet', 'connection', 'cache', 'how', 'what',
                'çevrimdışı', 'internet', 'yok', 'bağlantı', 'nasıl'],
  },

  // ── SETTINGS ─────────────────────────────────────────────────────────────

  {
    'title_type': 'settings_account',
    'doc_type': 'faq',
    'source_key': 'settings',
    'content':
        'How do I update my account details? Go to Settings in the Sidebar menu '
        'to change your display name and profile picture. Email changes require '
        're-authentication. You can also delete your account from this screen. '
        // TR
        'Hesap bilgilerimi nasıl güncellerim? Kenar çubuğu menüsündeki Ayarlar\'a '
        'giderek görünen adınızı ve profil fotoğrafınızı değiştirebilirsiniz. '
        'E-posta değişiklikleri yeniden kimlik doğrulaması gerektirir.',
    'indexes': ['settings', 'account', 'profile', 'update', 'change', 'how',
                'ayarlar', 'hesap', 'profil', 'güncelle', 'nasıl'],
  },
  {
    'title_type': 'settings_language',
    'doc_type': 'faq',
    'source_key': 'settings',
    'content':
        'How do I change the app language? Go to Settings → Language and choose '
        'from the supported languages. The AI assistant supports both English '
        'and Turkish commands regardless of the interface language setting. '
        // TR
        'Uygulama dilini nasıl değiştiririm? Ayarlar → Dil bölümüne gidin ve '
        'desteklenen diller arasından seçin. Yapay zeka asistanı arayüz dil '
        'ayarından bağımsız olarak Türkçe ve İngilizce komutları destekler.',
    'indexes': ['settings', 'language', 'turkish', 'english', 'change', 'how',
                'ayarlar', 'dil', 'türkçe', 'değiştir', 'nasıl'],
  },

  // ── ONBOARDING ───────────────────────────────────────────────────────────

  {
    'title_type': 'onboarding_first_steps',
    'doc_type': 'onboarding',
    'source_key': 'onboarding',
    'content':
        'Getting started with LifeStable: After signing up, create your first '
        'domain for a life area (like "University" or "Work"), then add tasks '
        'inside it. Use the AI assistant via the Sidebar menu to add tasks '
        'quickly with voice or text. Enable the Habit Tracker to build routines. '
        // TR
        'LifeStable\'a başlarken: Kaydolduktan sonra "Üniversite" veya "İş" '
        'gibi bir yaşam alanı için ilk alanınızı oluşturun, ardından içine '
        'görevler ekleyin. Kenar çubuğu menüsündeki Yapay Zeka Asistanını '
        'sesli veya metin komutlarıyla kullanın.',
    'indexes': ['start', 'begin', 'first', 'setup', 'onboarding', 'how',
                'başla', 'ilk', 'kurulum', 'nasıl'],
  },
  {
    'title_type': 'onboarding_points_levels',
    'doc_type': 'onboarding',
    'source_key': 'onboarding',
    'content':
        'How do points and levels work? You earn XP points by completing tasks, '
        'maintaining habit streaks, and achieving milestones. Accumulate enough '
        'points to level up. Your level and streak are displayed on your profile. '
        // TR
        'Puanlar ve seviyeler nasıl çalışır? Görevleri tamamlayarak, alışkanlık '
        'serilerini sürdürerek ve kilometre taşlarına ulaşarak XP puanı '
        'kazanırsınız. Yeterince puan toplayarak seviye atlarsınız.',
    'indexes': ['points', 'level', 'xp', 'earn', 'how', 'what',
                'puan', 'seviye', 'xp', 'kazan', 'nasıl', 'nedir'],
  },
];
