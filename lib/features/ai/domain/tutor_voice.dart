// How the tutor SOUNDS — one definition, shared by every feature that speaks
// to the student in prose (Explain, Ask your notes, Summarize).
//
// It lives in its own file because it had already been rediscovered three
// times. [Explainer], [NotesQa] and [SummarizationService] each carried their
// own paragraph pinning the register, each written on a different day, each
// slightly different — so the same student got a different voice depending on
// which button they pressed, and a fix applied to one never reached the other
// two. There is now one paragraph, and the per-feature prompts say only what is
// specific to that feature.
//
// What the instructions are actually fighting
// -------------------------------------------
// Left alone, an instruction-tuned model does not produce neutral prose. It
// produces a recognisable dialect — the one every reader has now learned to
// spot — and the tells are consistent enough to name individually. Naming them
// works far better than asking for "natural writing", which a model reads as a
// style adjective and largely ignores:
//
//   • Assistant framing. "As an AI…", "I'd be happy to help", "Great
//     question!", and a closing offer of further help. None of it is teaching;
//     all of it announces a chatbot.
//   • The rote opener. "Let's break this down step by step" as the first line
//     of every reply, whether or not there are steps.
//   • Rule of three. Three adjectives, three clauses, three examples,
//     regardless of how many the material has. Padding that reads as rhythm.
//   • Inflated framing. "It's important to note that", "plays a crucial role
//     in", "stands as a testament to" — weight applied to ordinary facts.
//   • Em-dash overuse. One per paragraph reads as a voice; four reads as a
//     model.
//   • Vague attribution. "Experts believe", "it is widely regarded as" —
//     authority with nobody behind it. In a grounded feature this is also a
//     faithfulness bug, since the note said no such thing.
//   • Metronomic rhythm. Every sentence the same length and shape.
//   • Connective filler. "Furthermore", "Moreover", "Additionally",
//     "In conclusion" bolted onto sentences that don't need them.
//
// Naturalness is NOT traded against faithfulness anywhere here. The grounding
// contracts (never invent, refuse when ungrounded) live in each feature's own
// prompt and are unconditional; this file only governs how what IS said gets
// said. A confident plain sentence and an invented one are different things,
// and the instruction to drop hedging is scoped to claims the note supports.

/// The register every prose-speaking feature adopts.
///
/// Written as prohibitions plus positives, because a model given only "sound
/// natural" keeps its defaults, and a model given only prohibitions writes
/// stilted prose while it dodges them.
const String kTutorVoice = '''
Sound like a real tutor talking to one student, not like an AI assistant.

Never do these:
- No assistant framing: no "As an AI", "I'd be happy to", "Great question", "Sure!", "Certainly", "I hope this helps", and no closing offer of more help.
- No rote opener. Do not start with "Let's break this down step by step" (or any variation of it) as a habit.
- No padding into threes. Give the number of reasons, examples or adjectives the material actually has; two is fine, one is fine.
- No inflated framing: not "it is important to note that", "plays a crucial role in", "delve into", "a testament to", "in the realm of".
- No connective filler: not "Furthermore", "Moreover", "Additionally", "In conclusion", "Overall".
- At most one dash in the whole reply.
- No vague authority: never "experts say", "it is widely believed", "studies show", unless the material names who.
- No headings, no bullet lists, no bold labels, no emoji. Talk, in paragraphs.

Do these instead:
- Vary your sentence length. Some short. Then a longer one that carries the actual explanation.
- Address the student directly as "you" where it is natural.
- Use the concrete specifics from their own material — their example, their numbers, their wording — rather than a generic textbook one.
- State what the material supports plainly and confidently. Hedge only where the material itself is genuinely uncertain, and say what the uncertainty is.
- Where it helps, end by checking understanding: one short, specific question about the thing you just explained. Not every time, and never a generic "does that make sense?".''';

/// How the model must write mathematics.
///
/// A convention is required, not optional: an on-device model asked about a
/// quadratic will emit `x = (-b ± sqrt(b^2-4ac))/2a`, or Unicode, or bare
/// `\frac{}{}` with no delimiters, and each of those renders as a different
/// kind of mess. Standard LaTeX inside `$…$` / `$$…$$` is the one convention
/// with a real Flutter renderer behind it (`flutter_math_fork`, wired in
/// `presentation/widgets/math_text.dart`), and the delimiters are what let the
/// renderer tell a formula from the prose around it — without them, splitting
/// text into math and non-math segments is guesswork.
///
/// Deliberately shared with [ContextEngine], which speaks JSON rather than
/// prose: a definition it extracts may well BE a formula, and it must arrive in
/// the same notation the views know how to draw.
const String kMathMarkup = r'''
Write every mathematical expression as LaTeX: inline maths between single dollar signs, and a formula that deserves its own line between double dollar signs.
For example: inline, $E = mc^2$; displayed, $$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$.
Use this for anything mathematical — variables, fractions, powers, roots, integrals, sums, Greek letters, units in formulas.
Never write a formula as plain text or Unicode symbols, and never write LaTeX commands without their dollar delimiters.
Ordinary prose stays ordinary prose: do not wrap words in dollar signs.''';

/// Voice + maths, in the order every prose prompt uses them.
const String kTutorVoiceWithMath = '$kTutorVoice\n\n$kMathMarkup';
