import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL = URL(string: "https://guopsgfcnfdawtnzgqzr.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1b3BzZ2ZjbmZkYXd0bnpncXpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2MzE1MTksImV4cCI6MjA4NzIwNzUxOX0.JQNpgBf_fKAgG2g7QNMmP_vrc08lROC3751lrCzD4uw"
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
