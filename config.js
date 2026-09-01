// Ledger configuration.
//
// The anon key is meant to be public — it grants nothing on its own. Row level
// security decides who can read and write.
window.LEDGER_CONFIG = {
  supabaseUrl: 'https://snfukbofyadfrhuaggad.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNuZnVrYm9meWFkZnJodWFnZ2FkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNjY3NzUsImV4cCI6MjEwMzg0Mjc3NX0.VS7OJ0vTK97AITaiXcuoTE-cJ3-jdADT1fzniDtPTfo',

  // The shared team account. Everyone signs in with one access code instead of
  // their own login. This address is only a username — the code is the secret,
  // and it is never stored here.
  // Blank this out to go back to per-person sign-in.
  sharedEmail: 'team@projectdrex-sales.com'
};
