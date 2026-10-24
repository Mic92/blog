---
title: "Building a personal voice assistant with an attitude in 2026"
date: 2026-10-24T10:09:32+02:00
---

In 2020, I got into voice assistants when I started playing around with
[rhasspy](https://github.com/rhasspy/). Back then, one had to mix and match a
lot of different components and services to find something usable, and it was
brittle as hell.
[Opensource deep-learning based text to speech](https://github.com/mozilla/TTS)
was still very fresh and would often still get stuck on short words. The only
useable wakeword detection was a commercial production by the name
[porcupine](https://picovoice.ai/products/voice/wake-word/). But it was fun to
set up my own because I could give it a personality, compared to the too-clean
commercial alternatives.

Skipping forward to 2026, TTS/STT/wakeword detection has made a lot of progress,
both in terms of system resources and in detection performance. And thanks to
agents, I can now have my own sassy personal agent written in the
[language](https://rust-lang.org/) of the Gods in one binary, rather than having
to glue Python microservices together.

This assistant runs as a background service on my desktop. Thanks to
[microwakeword](https://microwakeword.com/), wakeword detection now uses as
little as 0.5% CPU. It still misfires every once in a while, but thanks to a
second check using [whisper.cpp](https://github.com/ggml-org/whisper.cpp), I can
get rid of the vast majority of the misfires.

The text-to-speech engine is powered by
[KittenTTS](https://github.com/KittenML/KittenTTS), based on kitten-tts-nano,
which is a 30MB model - I configured it for the "bella" voice (try: nix run
github:Mic92/puss-say -- "Hello, world!"). The intent parser is home-grown,
inspired by [hassil](https://github.com/OHF-Voice/hassil)/rhasspy. It is tightly
coupled with the speech-to-text engine
[whisper.cpp](https://github.com/ggml-org/whisper.cpp), i.e. its grammar is used
by the speech-to-text engine to fuzzy-match what was said.

Unrecognized requests are logged so that I can later have agents extend the
assistant's capabilities.

Everything is set up to stream from one component to the next to keep the
latency low.

## So what can it do today?

- general info about time, date, weather, battery, uptime, calendar, mail, maths
  and the clipboard
- meetings: it reads my [khal](https://github.com/pimutils/khal)-based calendar
  and can create events with
  [calendar-cli](https://github.com/Mic92/mics-skills/tree/main/calendar-cli)
- it can create reminders/todos/shopping list entries
  ([todoman](https://github.com/pimutils/todoman))
- timers: I use [noctalia](https://github.com/noctalia-dev/noctalia) and it can
  manage the timers
- media: start/stop mpris-based players and start radio stations, including
  [radio lassulus](https://radio.lassul.us/)
- volume: increase/decrease pipewire outputs with wpctl
- start apps
- shut down/reboot/suspend/lock the system
- search the web with kagi
- look up news
- play games/tell jokes
- various sassy responses

## What's next?

I am currently recording wakeword samples and hoping to have enough of them to
train my own personal version that doesn't fire on podcasts or trolls calling
'Alexa'.

The language the assistant understands is still limited to what the grammar
supports, but thanks to agents, it's quite easy to generate a lot of possible
alternative commands. Now, one could get the sledgehammer out and try to use
some language model as a fallback, but maybe there are some other classifiers
that don't require spinning up the GPUs and might do the job as well.

The code can be found
[here](https://github.com/Mic92/dotfiles/tree/main/pkgs/voice-assistant). It's
not meant to be a generic, customizable project for everyone, but rather a
project fitted to my use cases.

But I think it might be a good template in case someone else wants to build the
same and doesn't want to do the research on what frameworks/models to pull in.
