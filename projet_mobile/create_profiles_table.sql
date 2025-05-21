-- Créer la table profiles si elle n'existe pas
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  face_image_path TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Créer une politique RLS pour permettre la lecture publique
CREATE POLICY "Tout le monde peut lire les profils"
ON profiles FOR SELECT
USING (true);

-- Créer une politique RLS pour permettre aux utilisateurs de modifier leur propre profil
CREATE POLICY "Les utilisateurs peuvent modifier leur propre profil"
ON profiles FOR UPDATE
USING (auth.uid() = id);

-- Créer une politique RLS pour permettre aux utilisateurs de supprimer leur propre profil
CREATE POLICY "Les utilisateurs peuvent supprimer leur propre profil"
ON profiles FOR DELETE
USING (auth.uid() = id);

-- Créer une politique RLS pour permettre l'insertion de profils
CREATE POLICY "Les utilisateurs peuvent insérer des profils"
ON profiles FOR INSERT
WITH CHECK (true);

-- Activer RLS sur la table profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;