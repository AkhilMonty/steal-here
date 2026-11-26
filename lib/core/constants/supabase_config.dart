
class SupabaseConfig {
SupabaseConfig._();

// Replace these placeholders with your Supabase project details.
static const String supabaseUrl = 'https://lhzbgfnnchqgpyhdyoja.supabase.co';
static const String publishableKey = 'sb_publishable_v_dshqGSW36wAF8BymVe6g_DXAE_UTy';

static bool get isConfigured {
return supabaseUrl.startsWith('https://') &&
!supabaseUrl.contains('YOUR_SUPABASE') &&
publishableKey.isNotEmpty &&
!publishableKey.contains('YOUR_SUPABASE');
}
}
