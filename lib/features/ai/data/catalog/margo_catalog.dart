// The cloud models Margo itself provides: free, budget and premium.
//
// None of them can answer yet. Margo's gateway serves no model list today, so
// these are listed as "coming soon" and cannot be picked. When the gateway
// serves its catalogue (docs/AI_TUTOR_PLAN.md, part 3) this list becomes the
// fallback shown before the first successful fetch.

import '../../domain/catalog/ai_model_entry.dart';
import '../../domain/catalog/user_connection.dart'
    show kUnknownModelWindowTokens;

const List<AiModelEntry> kBundledMargoCatalog = [
  AiModelEntry(
    id: 'margo:free',
    displayName: 'Margo Free',
    source: ModelSource.margo,
    tier: MargoTier.free,
    contextWindowTokens: kUnknownModelWindowTokens,
    available: false,
  ),
  AiModelEntry(
    id: 'margo:budget',
    displayName: 'Margo Budget',
    source: ModelSource.margo,
    tier: MargoTier.budget,
    contextWindowTokens: kUnknownModelWindowTokens,
    available: false,
  ),
  AiModelEntry(
    id: 'margo:premium',
    displayName: 'Margo Premium',
    source: ModelSource.margo,
    tier: MargoTier.premium,
    contextWindowTokens: kUnknownModelWindowTokens,
    locked: true,
    available: false,
  ),
];
