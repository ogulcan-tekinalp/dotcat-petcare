class AppConstants {
  static const String appName = 'PetCare';
  static const String appTagline = 'Pet Bakım Asistanı';

  // Reminder Types (Ortak - her iki pet için de)
  static const String reminderTypeFood = 'food';
  static const String reminderTypeMedicine = 'medicine';
  static const String reminderTypeVet = 'vet';
  static const String reminderTypeVaccine = 'vaccine';
  static const String reminderTypeGrooming = 'grooming';
  static const String reminderTypeWeight = 'weight';
  static const String reminderTypeDotcatComplete = 'dotcat_complete';

  // Kedi-Specific Reminder Types
  static const List<String> catReminderTypes = [
    'dotcat_complete',
    'vaccine',
    'medicine',
    'vet',
    'grooming',
    'food',
    'weight',
  ];

  // Köpek-Specific Reminder Types
  static const List<String> dogReminderTypes = [
    'vaccine',
    'medicine',
    'vet',
    'grooming',
    'food',
    'exercise',    // Köpeklere özel
    'walk',        // Köpeklere özel - Yürüyüş
    'training',    // Köpeklere özel - Eğitim
    'playtime',    // Köpeklere özel - Oyun zamanı
    'bath',        // Köpeklere özel - Banyo
    'weight',
  ];

  // Vaccine Types - CATS
  static const List<String> catVaccineTypes = [
    'vaccine_fvrcp',      // Feline Viral Rhinotracheitis, Calicivirus, Panleukopenia
    'vaccine_rabies',     // Kuduz
    'vaccine_felv',       // Feline Leukemia Virus
    'vaccine_fip',        // Feline Infectious Peritonitis
    'vaccine_other',
  ];

  // Vaccine Types - DOGS
  static const List<String> dogVaccineTypes = [
    'vaccine_dhpp',       // Distemper, Hepatitis, Parvovirus, Parainfluenza
    'vaccine_rabies',     // Kuduz
    'vaccine_bordetella', // Kennel Cough
    'vaccine_lepto',      // Leptospirosis
    'vaccine_lyme',       // Lyme Disease
    'vaccine_corona',     // Coronavirus
    'vaccine_other',
  ];

  // Common Cat Breeds
  static const List<String> catBreeds = [
    'Tekir',
    'Van Kedisi',
    'Ankara Kedisi',
    'British Shorthair',
    'Scottish Fold',
    'Persian',
    'Siamese',
    'Maine Coon',
    'Ragdoll',
    'Bengal',
    'Sphynx',
    'Melez',
    'Diğer',
  ];

  // Common Dog Breeds
  static const List<String> dogBreeds = [
    'Golden Retriever',
    'Labrador Retriever',
    'German Shepherd',    // Alman Kurdu
    'Kangal',
    'Akbash',            // Akbaş
    'Bulldog',
    'Poodle',            // Kaniş
    'Beagle',
    'Husky',
    'Chihuahua',
    'Pug',               // Mops
    'Boxer',
    'Dachshund',         // Jambon
    'Rottweiler',
    'Yorkshire Terrier',
    'Shih Tzu',
    'Maltese Terrier',   // Malta Köpeği
    'Pomeranian',
    'Cocker Spaniel',
    'Melez',
    'Diğer',
  ];

  // Dog Sizes
  static const List<String> dogSizes = [
    'Çok Küçük',  // Toy (< 5kg) - Chihuahua, Pomeranian
    'Küçük',      // Small (5-10kg) - Shih Tzu, Maltese
    'Orta',       // Medium (10-25kg) - Beagle, Cocker Spaniel
    'Büyük',      // Large (25-45kg) - Labrador, Golden Retriever
    'Çok Büyük',  // Giant (> 45kg) - Kangal, German Shepherd
  ];
}
