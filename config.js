// Réglages de Labo Techno. C'est le SEUL fichier à modifier.
// Laissez les guillemets. Si un réglage est vide, l'appli fonctionne quand même (mode essai, sur le téléphone).
window.LABO_CONFIG = {supabaseUrl , supabaseKey et sheetId 
  // 1. Supabase (comptes et suivi du groupe) : Project Settings > API
  supabaseUrl: "https://whcmevziuzmtwmxksbzx.supabase.co",          // ex. "https://abcdefgh.supabase.co"
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndoY21ldnppdXptdHdteGtzYnp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM5NzYzOTUsImV4cCI6MjEwOTU1MjM5NX0.otSwiIokBSDtaZNEcfovUfByQGcyFMc0oyJHyw8BTN0",          // la clé « anon public » (pas la clé « service_role » !)

  // 2. Google Sheet du contenu : l'identifiant dans l'adresse du tableur
  //    https://docs.google.com/spreadsheets/d/  CET_IDENTIFIANT  /edit
  sheetId: "",

  // 3. Code de l'espace formateur en mode essai (sans Supabase)
  pinFormateur: "1234"
};
