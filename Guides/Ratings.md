# Ratings

Part of the [PharenSDK guides](../README.md#guides).

**An app-rating prompt is never presented from compiled rules alone.** The `ratings` policy you
write in the console — or through `PUT /v1/config/{app_id}` (sending the version it read as `If-Match`) or
the `pharen_set_rating_policy` tool, versioned with an actor and a note — is the precondition for every prompt: its
`enabled` is the only switch, and each threshold it names overrides the one compiled here. An
install that has not fetched a policy refuses every checkpoint as `config_pending`; one whose
document is older than its maximum age (`config_max_age_seconds` in the served document: seven
days, unless the platform has set another of at most thirty) refuses as `config_stale`, in either direction — a stale `on` does not prompt, and
a stale `off` is reported as stale. Both are queryable as `ratings.refusals`, grouped by the
rung that refused, which is the page to calibrate from. To stop prompting, write
`enabled: false`. Above every rung, a checkpoint the platform is not
providing ratings to — ratings withheld from your plan or by a protective lever, or an install it
is holding or no longer serving — refuses as `withheld`, however fresh the policy. So does every
checkpoint while the SDK is switched off, by `sdkKillSwitch` or by the platform — that refusal
reaches your app's own answer and is not sent, since a switched-off SDK sends nothing — and while
a full-screen notice stands in front of the app (an update required, a retired version, an outage,
a waiting line): a person who cannot use the app is not asked to rate it.

**The SDK never prompts on its own — unless the policy tells it to.** A checkpoint is a call
your app makes — `requestRatingIfEligible` below, or the ask-first pair — at a moment you
choose; the policy decides whether that moment becomes a prompt. Without the call there is no
checkpoint: a policy written in the console changes nothing on the device, and the platform
sees neither prompts nor refusals — the configuration page says so when no device has
reported a checkpoint in seven days.

The one exception is written in the policy itself. A `timed_checkpoint` — `{foreground_seconds}`,
no floor — makes the SDK reach a checkpoint on its own, once per launch, once the app has
been in the foreground for that long in one stretch: the same ladder, the same bookkeeping,
the OS sheet, presented into the window scene that is active at that moment. No call in the
app is needed. With no foreground-active scene at that moment the checkpoint is refused as
`surface_unavailable` — nothing is recorded against the cooldown — and the next launch tries
again.

Every prompt or refusal it produces says `via: timed`, so `ratings.prompts` and
`ratings.refusals` grouped by `via` keep the timed checkpoint's checkpoints apart from your own.

How the wait is measured:

- **One stretch of use.** The clock runs while the app is in front and resets to zero when it
  leaves — "after 45 seconds" means 45 seconds without leaving the app. Ten seconds, away, ten
  seconds, away never adds up; if sessions are usually shorter than the wait, the timed checkpoint never
  fires (which is not a refusal: nothing is reported, and the console says no device has run
  the document in the foreground for that long). Set the wait below your typical session.
- **Once per launch.** Each process launch gets one firing, in the first stretch that lasts the
  wait. A quit — by the person, by the system reclaiming memory, or by a crash — starts a new
  process and a new clock. Every firing still has to pass the policy, so a person who relaunches
  often meets the cooldown and once-per-version rules, not a stream of sheets.
- **`foreground_seconds: 0` is the first foreground moment.** There is no minimum; the platform's
  throttle and your thresholds govern the rest.
- **It fires on time, not on context.** The person may be in the middle of something. If a
  prompt at a moment of your choosing matters, a checkpoint call at that moment is the better
  integration; the timed checkpoint is the one that needs no code. Use one or the other — with both,
  whichever comes first prompts.

The compiled part carries thresholds only, the numbers a policy of `{enabled: true}` inherits:

```swift
Pharen.start(granting: [.telemetry, .behavioral]) { config in
    config.ratings = PharenRatingSettings(minCheckpoints: 5)
}
```

`PharenRatingSettings` defaults: `minCheckpoints: 3`, `minLaunches: 0`,
`minDaysSinceInstall: 7`, `minSessionsSinceFailure: 0`, `cooldownDays: 122`, `oncePerVersion: true`.
Every field the policy
names wins; a field it leaves out keeps the compiled number.

**Not right after the app failed them.** `minSessionsSinceFailure`
(`ratings.min_sessions_since_failure` in the policy) is the number of SDK sessions that must have
completed since the app last failed the person, before it asks — the rule that keeps the ask away
from a person who just watched the app die, however it died. A failure is a process death in the
foreground the person did not cause: a crash report, or a foreground exit no report describes (a
memory kill, a watchdog kill); a background death and the person's own quit are not failures. A
failure resets the run to zero; a session completes when the app returns after the inactivity
timeout or is still in use when the session's lifetime ends, or when a later launch finds it left open with no failure behind. The run is not private to the rule: every `session.start`
carries it as `sessions_since_failure`, with `failed_before` — whether a launch has ever found a
failure on this install, so a run of 0 reads as a fresh install's first session or the first after a failure —
and `session_number`, which session this is on the install (1 for the first). `sessions.count`
groups by them, so the policy can be read against what the fleet actually sees, and paired with
`crashes.count`. Each count is reported only when it is exact: an install from a build that
predates them reports no session number, and no run or flag until a launch finds a failure.

Where a condition goes: the checkpoint call below is yours to place — after the milestone
you choose — and a condition you check in code before calling it is invisible to the platform.
A condition written as a served trigger (`after_event`, `min_occurrences`) is versioned with the
policy and every unmet call is a `rating.refused{triggers_pending}`; a trigger counts an event
after the consent gate and before your session sample rate, so an occurrence in a session the
rate leaves out still counts toward the prompt it unlocks and nothing about it leaves the device.

Two integrations:

```swift
// One call: evaluate every rule and, if all pass, request the system dialog.
Pharen.shared?.ratings.requestRatingIfEligible(scene: windowScene)

// Ask first: "Enjoying the app? [Yes] [Not really]", then what your policy says follows.
switch Pharen.shared?.ratings.checkQuestionEligibility() {
case .eligible(let question):
    question.present()                       // the SDK's own card, in your app's tint
case .ineligible(let reason):
    print(reason)                            // PharenRatingIneligibleReason names the first rule that said no
case nil:
    break                                    // the SDK has not started
@unknown default:
    break                                    // an answer a later SDK adds: ask nothing
}
```

**The rating question.** `checkQuestionEligibility()` climbs the same rules as the sheet and hands
back a `PharenRatingQuestion` — the only way to show the question and to continue from its answer.
Your app chooses the moment; `present()` draws the card: one question and two answers in your
app's tint, with no other mark on any plan, following the person's text size, VoiceOver,
keyboard, motion, appearance and reading direction. The card records that it was shown and how
it was answered — closing it unanswered is `dismissed`, not a No. `present()` returns `false`,
and records nothing, when there is no foreground scene to present from or one is mid-transition
(present again in a moment), or when since the check the SDK was switched off or is withholding
prompts, ratings were withheld, the policy went off or stale, or another prompt spent what this
one would.

What an answer leads to is the policy's, not your code's: `ratings.question.on_yes` and `on_no`
each name `none` (the default — the answer is recorded, nothing follows), `feedback` (the SDK's
feedback sheet), `rating` (the system rating sheet, which iOS may decline to show), or `review`
(the App Store's write-a-review page; the platform serves the App Store id, and without one a
question with a `review` answer is not asked — `surface_unavailable`). A dismissal runs nothing.
The question keeps its own cooldown and once-per-version (`ratings.question.cooldown_days`,
`once_per_version`), apart from the sheet's, so a policy can ask the question now and present the
sheet later; both draw on the one prompt budget. The wording is served too (`text`, `yes_label`,
`no_label`, with `{app_name}` in the question): each string is the served text in the person's
language, then the SDK's built-in text in it, then the served `default` (a single string is
every language); with
`untranslated: skip`, a person whose language the served wording does not cover is not asked
(`untranslated`). Under `ratings.timed_checkpoint.style: question` the timed checkpoint asks the
question with the SDK's card instead of presenting the sheet.

Apple and Google publish rules on how apps may ask for ratings and reviews; you are responsible
for configuring prompting in line with them.

What is emitted, and what it means. `rating.prompted` (`surface: "os_native"`) means the
system dialog was *requested* — iOS gives no way to know whether it appeared, or what the
person did; with `follows: "question"` it is the sheet a Yes led to, the follow-up of an ask
already counted, never a second one. `rating.prompted` (`surface: "question"`) means a person
saw the question. `rating.accepted` / `rating.declined` are never inferred: they are the
question's answers, with `surface: "question"`, the `action` that followed, and on a dismissal
`dismiss_reason: "not_now"`. `rating.refused` reports a checkpoint
the rules declined, naming the first rule that failed — `config_pending` and `config_stale`
before any threshold — so a policy that refuses every moment is distinguishable from a moment
that never fired, and an install no policy has reached from one the policy said no to. Call the checkpoint methods at a natural
moment (after a completed task or purchase), never in a loop: each call counts toward
`minCheckpoints`.
