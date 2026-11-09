# Sourced by tests/run: the hook script, fed the JSON that Claude Code sends.

export CLAUDE_PLUGIN_DATA="$work/data"
unset THINGS_IDLE THINGS_REPEAT_SECONDS
# The first part tests one idle period without the repeat. The repeat has its own part below.
export THINGS_REPEAT=off THINGS_TICK=1

stop_input() { # stop_input SESSION MESSAGE
  jq -n --arg s "$1" --arg m "$2" --arg c "$here" \
    '{session_id: $s, cwd: $c, hook_event_name: "Stop", stop_hook_active: false, last_assistant_message: $m}'
}
idle_input() { # idle_input SESSION
  jq -n --arg s "$1" --arg c "$here" \
    '{session_id: $s, cwd: $c, hook_event_name: "Notification", notification_type: "idle_prompt", message: "Claude is waiting for your input"}'
}
stop() { stop_input "$1" "$2" | "$hook" stop; }
idle() { idle_input "$1" | "$hook" idle 2> "$work/idle.err"; }
wakes() { idle "$1"; [ $? -eq 2 ]; }
stays_quiet() { idle "$1"; [ $? -eq 0 ]; }
in_message() { grep -q -- "$1" "$work/idle.err"; }
told_count() { [ "$(wc -l < "$work/data/sessions/$1/told")" -eq "$2" ]; }

fact_reply="**Things you probably didn't know about things**

The hook keeps one folder per session under the plugin's data folder.
Source: \`hooks/things-hook:20\`"
fact="The hook keeps one folder per session under the plugin's data folder."

stop s1 "Done. The review is running."
check "after a normal reply, idle wakes Claude (exit 2)" wakes s1
check "the wake message names the project" in_message "one fact about things"
check "the wake message names the skill" in_message "Use the things skill"
check "the first wake lists no facts" eval '! in_message "already told"'

stop s1 "$fact_reply"
check "the fact in the reply is recorded" grep -qxF "$fact" "$work/data/sessions/s1/told"
check "after the fact, idle stays quiet (THINGS_REPEAT=off)" stays_quiet s1
check "a second idle in the same period stays quiet (THINGS_REPEAT=off)" stays_quiet s1

stop s1 "Round 2 is open."
check "the next normal reply starts a new period: idle wakes again" wakes s1
check "the second wake lists the fact told" in_message "^- $fact"

stop s1 "I could not find a fact that meets the rules."
check "the reply to a wake ends the period even without a fact" stays_quiet s1
check "a reply without the heading records nothing" told_count s1 1

stop s2 "$fact_reply"
check "a fact the user asked for also quiets the next idle" stays_quiet s2
check "a fact the user asked for is recorded" told_count s2 1

stop s3 "Hello."
check "each session has its own state" wakes s3

stop s4 "Waiting for the review."
check "THINGS_IDLE=off turns the wake off" eval 'idle_input s4 | THINGS_IDLE=off "$hook" idle'

# A bad input: both hooks exit 0 and write nothing at all, in a data folder of its own.
ignored() { # ignored INPUT
  for command in idle stop prompt; do
    printf '%s' "$1" | CLAUDE_PLUGIN_DATA="$work/bad" "$hook" "$command" 2> /dev/null || return 1
  done
  [ ! -e "$work/bad" ]
}
check "an input that is not JSON is ignored" ignored 'not json'
check "an object followed by garbage is ignored" ignored '{"session_id":"broken"} garbage'
check "two objects are ignored" ignored '{"session_id":"a"} {"session_id":"b"}'
check "an array is ignored" ignored '[{"session_id":"a"}]'
check "a missing session id is ignored" ignored '{"cwd":"/"}'
check "a session id that is not a string is ignored" ignored '{"session_id":42}'
for id in . .. ../ ../.. ../../escape a/b 'a b' '.hidden' 'x.y'; do
  check "the session id '$id' is ignored" ignored "$(jq -n --arg s "$id" '{session_id: $s}')"
done

# The cleanup: a session idle for over two weeks is removed, an active one is kept.
# old-active has its state files before it ages, so only the hook's own touch keeps it.
stop old-active "$fact_reply"
stop old-gone "Hello."
touch -t 202601010000 "$work/data/sessions/old-active" "$work/data/sessions/old-gone"
stop old-active "$fact_reply"
check "an old session that is active again keeps its state" told_count old-active 2
check "the session that becomes active again stays quiet after its fact" stays_quiet old-active
check "a session idle for over two weeks is removed" test ! -e "$work/data/sessions/old-gone"
mkdir -p "$work/empty-path"
check "without jq the hooks do nothing" eval 'idle_input s5 | PATH="$work/empty-path" "$hook" idle'
check "an unknown command fails with usage" eval 'echo "{}" | "$hook" other 2>&1; [ $? -eq 64 ]'

# The repeat: after a fact, the next idle waits THINGS_REPEAT minutes, then wakes again. Here the
# repeat is 2 seconds (THINGS_REPEAT_SECONDS) and the hook checks for a cancel every second.
unset THINGS_REPEAT
export THINGS_REPEAT_SECONDS=2
prompt() { jq -n --arg s "$1" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: "hi"}' | "$hook" prompt; }
timed_idle() { # timed_idle SESSION: runs idle, sets $code and $took (seconds)
  start="$(date +%s)"
  idle "$1"
  code=$?
  took=$(($(date +%s) - start))
}
# idle_in_background SESSION NAME: starts idle, its exit code lands in $work/NAME.code
idle_in_background() {
  (
    idle_input "$1" | "$hook" idle 2> /dev/null
    echo $? > "$work/$2.code"
  ) &
}
code_of() { # code_of NAME: waits up to 10 seconds for the code of a background idle
  tries=0
  while [ ! -s "$work/$1.code" ] && [ "$tries" -lt 20 ]; do
    sleep 0.5 2> /dev/null || sleep 1
    tries=$((tries + 1))
  done
  cat "$work/$1.code" 2> /dev/null
}

stop r1 "$fact_reply"
timed_idle r1
check "after a fact, idle waits for the repeat and then wakes" eval '[ "$code" -eq 2 ] && [ "$took" -ge 1 ]'
check "the repeat wake lists the facts told" in_message "^- $fact"

stop r1 "$fact_reply"
echo 0 > "$work/data/sessions/r1/last-fact"
timed_idle r1
check "a repeat already due wakes at once" eval '[ "$code" -eq 2 ] && [ "$took" -le 1 ]'

stop r2 "$fact_reply"
idle_in_background r2 cancel-prompt
sleep 1
prompt r2
check "a prompt cancels the waiting repeat" test "$(code_of cancel-prompt)" = 0
check "the prompt hook prints nothing (its stdout would reach Claude)" test -z "$(prompt r2)"

stop r3 "$fact_reply"
idle_in_background r3 cancel-stop
sleep 1
stop r3 "Back to work."
check "a normal reply cancels the waiting repeat" test "$(code_of cancel-stop)" = 0
check "after that reply, idle wakes at once (a new period)" wakes r3

stop r4 "$fact_reply"
idle_in_background r4 older
sleep 1
idle_in_background r4 newer
check "a newer idle hook replaces an older one" eval '[ "$(code_of newer)" = 2 ] && [ "$(code_of older)" = 0 ]'

# No limit on the count: twelve repeats in a row all wake (each one already due).
many_repeats() {
  i=0
  while [ "$i" -lt 12 ]; do
    stop r5 "$fact_reply"
    echo 0 > "$work/data/sessions/r5/last-fact"
    idle_input r5 | "$hook" idle 2> /dev/null
    [ $? -eq 2 ] || return 1
    i=$((i + 1))
  done
}
check "the repeats have no limit" many_repeats
generation_before="$(cat "$work/data/sessions/r5/generation")"
prompt r5
check "the prompt of our own wake does not cancel anything" \
  test "$(cat "$work/data/sessions/r5/generation")" = "$generation_before"

stop r6 "$fact_reply"
check "THINGS_REPEAT=off turns only the repeat off" eval 'idle_input r6 | THINGS_REPEAT=off "$hook" idle'
check "THINGS_REPEAT=0 turns the repeat off too" eval 'idle_input r6 | THINGS_REPEAT=0 THINGS_REPEAT_SECONDS= "$hook" idle'

# Settings with leading zeroes are decimal, and a huge value is capped (no arithmetic error).
# last-fact 0 makes any repeat due at once; THINGS_REPEAT_SECONDS is unset so THINGS_REPEAT counts.
stop n1 "$fact_reply"
echo 0 > "$work/data/sessions/n1/last-fact"
check "THINGS_REPEAT=08 works (not octal)" eval 'idle_input n1 | THINGS_REPEAT=08 THINGS_REPEAT_SECONDS= "$hook" idle 2> /dev/null; [ $? -eq 2 ]'
stop n2 "$fact_reply"
echo 0 > "$work/data/sessions/n2/last-fact"
check "a huge THINGS_REPEAT is capped" eval 'idle_input n2 | THINGS_REPEAT=99999999999999999999 THINGS_REPEAT_SECONDS= "$hook" idle 2> /dev/null; [ $? -eq 2 ]'
stop n3 "$fact_reply"
echo $(($(date +%s) - 540)) > "$work/data/sessions/n3/last-fact"
(
  idle_input n3 | THINGS_REPEAT=010 THINGS_REPEAT_SECONDS= "$hook" idle 2> /dev/null
  echo $? > "$work/n3.code"
) &
sleep 2
check "THINGS_REPEAT=010 is ten minutes, not eight: still waiting after nine" test ! -e "$work/n3.code"
prompt n3
code_of n3 > /dev/null

# The races: a prompt or a reply between the hook's start and its wake must cancel the wake.
# THINGS_TEST_PAUSE stops the hook at a point until the test writes resume-POINT.
paused_idle() { # paused_idle SESSION POINT NAME: starts idle and waits until it stops at POINT
  (
    idle_input "$1" | THINGS_TEST_PAUSE="$2" "$hook" idle 2> /dev/null
    echo $? > "$work/$3.code"
  ) &
  tries=0
  until [ -e "$work/data/sessions/$1/paused-$2" ] || [ "$tries" -ge 50 ]; do
    sleep 0.2 2> /dev/null || sleep 1
    tries=$((tries + 1))
  done
}
resume() { touch "$work/data/sessions/$1/resume-$2"; }
no_wake() { # no_wake SESSION NAME: the paused idle exited 0 and set no pending wake
  [ "$(code_of "$2")" = 0 ] && [ ! -e "$work/data/sessions/$1/pending" ]
}

stop c1 "$fact_reply"
paused_idle c1 started c1
prompt c1
resume c1 started
check "a prompt before the repeat wait starts cancels it" no_wake c1 c1

stop c2 "$fact_reply"
echo 0 > "$work/data/sessions/c2/last-fact"
paused_idle c2 claim c2
prompt c2
resume c2 claim
check "a prompt after the wait, before the wake is claimed, cancels it" no_wake c2 c2

stop c3 "$fact_reply"
echo 0 > "$work/data/sessions/c3/last-fact"
paused_idle c3 claim c3
stop c3 "Back to work."
resume c3 claim
check "a reply after the wait, before the wake is claimed, cancels it" no_wake c3 c3

stop c4 "Done."
paused_idle c4 claim c4
prompt c4
resume c4 claim
check "a prompt cancels a first wake that is not claimed yet" no_wake c4 c4

stop c5 "Done."
paused_idle c5 claim c5
resume c5 claim
check "without a prompt, the paused first wake goes on" eval '[ "$(code_of c5)" = 2 ] && [ -e "$work/data/sessions/c5/pending" ]'
