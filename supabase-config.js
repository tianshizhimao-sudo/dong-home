// Supabase 配置 - 填入你的项目信息
const SUPABASE_URL = 'YOUR_SUPABASE_URL'; // 例如: https://xxxxx.supabase.co
const SUPABASE_KEY = 'YOUR_SUPABASE_ANON_KEY'; // 例如: eyJhbGciOiJIUzI1NiIs...

// 初始化 Supabase 客户端
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// 家庭ID - 用于区分不同家庭的数据
const FAMILY_ID = 'dong-olivia';

// ========== Supabase 同步函数 ==========

async function supabaseInit() {
  // 检查表是否存在，如果不存在则使用本地数据
  try {
    const { data, error } = await supabase
      .from('inventory')
      .select('*')
      .eq('family_id', FAMILY_ID)
      .single();
    
    if (error && error.code === 'PGRST116') {
      // 没有数据，插入初始数据
      await supabaseSave(inventory);
    } else if (data) {
      // 有云端数据，检查是否需要更新本地
      const cloudTime = new Date(data.updated_at).getTime();
      const localTime = new Date(settings.lastSync || 0).getTime();
      
      if (cloudTime > localTime) {
        inventory = data.items;
        localStorage.setItem('home-inventory', JSON.stringify(inventory));
        settings.lastSync = data.updated_at;
        saveSettings();
        renderAll();
        updateSyncStatus('⬇️ 已从云端同步', 'synced');
      } else {
        updateSyncStatus('✅ 已是最新', 'synced');
      }
    }
    
    // 订阅实时更新
    subscribeToChanges();
    
  } catch (e) {
    console.error('Supabase init error:', e);
    updateSyncStatus('⚠️ 离线模式', 'error');
  }
}

async function supabaseSave(items) {
  try {
    updateSyncStatus('⏳ 同步中...', 'syncing');
    
    const { data, error } = await supabase
      .from('inventory')
      .upsert({
        family_id: FAMILY_ID,
        items: items,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'family_id'
      });
    
    if (error) throw error;
    
    settings.lastSync = new Date().toISOString();
    saveSettings();
    updateSyncStatus('✅ 已同步', 'synced');
    
  } catch (e) {
    console.error('Supabase save error:', e);
    updateSyncStatus('❌ 同步失败', 'error');
  }
}

function subscribeToChanges() {
  supabase
    .channel('inventory-changes')
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'inventory',
      filter: `family_id=eq.${FAMILY_ID}`
    }, (payload) => {
      console.log('实时更新:', payload);
      if (payload.new && payload.new.items) {
        // 检查是否是自己的更新（避免循环）
        const cloudTime = new Date(payload.new.updated_at).getTime();
        const localTime = new Date(settings.lastSync || 0).getTime();
        
        if (cloudTime > localTime + 1000) { // 1秒容差
          inventory = payload.new.items;
          localStorage.setItem('home-inventory', JSON.stringify(inventory));
          settings.lastSync = payload.new.updated_at;
          saveSettings();
          renderAll();
          showToast('📱 数据已从其他设备同步');
          updateSyncStatus('⬇️ 刚刚同步', 'synced');
        }
      }
    })
    .subscribe();
}

function updateSyncStatus(text, className) {
  const status = document.getElementById('syncStatus');
  if (status) {
    status.textContent = text;
    status.className = 'sync-status ' + (className || '');
  }
}

// 修改原有的 saveData 函数，添加云同步
const originalSaveData = saveData;
saveData = function() {
  originalSaveData();
  // 延迟同步，避免频繁写入
  clearTimeout(window.syncTimeout);
  window.syncTimeout = setTimeout(() => {
    if (typeof supabaseSave === 'function') {
      supabaseSave(inventory);
    }
  }, 2000);
};

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', () => {
  setTimeout(supabaseInit, 1000);
});
