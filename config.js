// Online sync configuration.
//
// Leave both blank and the ledger works exactly as it does now: everything
// stays in this browser and nothing is sent anywhere.
//
// Fill both in (Supabase → Project Settings → API) and the ledger signs in and
// syncs across devices. The anon key is meant to be public — it grants nothing
// on its own; row level security is what protects the data.
window.LEDGER_CONFIG = {
  supabaseUrl: '',      // e.g. 'https://abcdefgh.supabase.co'
  supabaseAnonKey: ''   // the long "anon public" key
};
