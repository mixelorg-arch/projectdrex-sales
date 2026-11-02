// Ledger configuration.
//
// The anon key is meant to be public — it grants nothing on its own. Row level
// security decides what each signed-in role may read and write.
window.LEDGER_CONFIG = {
  supabaseUrl: 'https://snfukbofyadfrhuaggad.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNuZnVrYm9meWFkZnJodWFnZ2FkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNjY3NzUsImV4cCI6MjEwMzg0Mjc3NX0.VS7OJ0vTK97AITaiXcuoTE-cJ3-jdADT1fzniDtPTfo',

  // Two shared logins. These addresses are usernames only — each one's access
  // code is its account password, held in Supabase and never written here.
  staffEmail: 'staff@projectdrex-sales.com',
  adminEmail: 'admin@projectdrex-sales.com'
};
