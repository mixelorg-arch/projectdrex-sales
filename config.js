// Online sync configuration.
//
// The anon key is meant to be public — it grants nothing on its own. Row level
// security (see supabase/schema.sql) is what decides who can read and write.
// Blank both values out and the ledger reverts to living only in this browser.
window.LEDGER_CONFIG = {
  supabaseUrl: 'https://snfukbofyadfrhuaggad.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNuZnVrYm9meWFkZnJodWFnZ2FkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNjY3NzUsImV4cCI6MjEwMzg0Mjc3NX0.VS7OJ0vTK97AITaiXcuoTE-cJ3-jdADT1fzniDtPTfo'
};
