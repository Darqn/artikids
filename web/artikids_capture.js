(() => {
  const asset = (name) => new URL(`vision/${name}`, document.baseURI).href;
  let active;
  let playing;
  let visionModule;

  function stop() {
    if (playing) {
      playing.finish(false);
    }
    const session = active;
    active = null;
    if (!session) return;

    cancelAnimationFrame(session.frame);
    clearInterval(session.voiceTimer);
    for (const track of session.stream?.getTracks() ?? []) track.stop();
    if (session.video) {
      session.video.pause();
      session.video.srcObject = null;
    }
    if (session.audio && session.audio.state !== "closed") {
      session.audio.close().catch(() => {});
    }
    session.landmarker?.close();
  }

  function fail(session, error) {
    if (active !== session) return;
    stop();
    session.emit(JSON.stringify({ error }));
  }

  function trackFace(session) {
    let previousFrame = -1;
    let previousCapture = -Infinity;
    const frame = (now) => {
      if (active !== session) return;

      if (session.video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
          session.video.currentTime !== previousFrame && now - previousCapture >= 60) {
        previousFrame = session.video.currentTime;
        previousCapture = now;
        try {
          const result = session.landmarker.detectForVideo(session.video, now);
          const faces = result.faceLandmarks.length;
          const categories = faces === 1 ? result.faceBlendshapes[0]?.categories : [];
          const scores = new Map((categories ?? []).map((item) => [item.categoryName, item.score]));
          const score = (name) => scores.get(name) ?? 0;
          session.emit(JSON.stringify({
            time: Math.round(now),
            faces,
            open: score("jawOpen"),
            smile: (score("mouthSmileLeft") + score("mouthSmileRight")) / 2,
            round: score("mouthPucker"),
          }));
        } catch (_) {
          fail(session, "Не удалось обработать изображение. Запусти камеру снова.");
          return;
        }
      }

      session.frame = requestAnimationFrame(frame);
    };
    session.frame = requestAnimationFrame(frame);
  }

  // Require periodic energy in a short audio window. The clinician judges the vowel.
  function hasVoice(samples) {
    const mean = samples.reduce((sum, value) => sum + value, 0) / samples.length;
    let energy = 0;
    for (let i = 0; i < samples.length; i++) {
      samples[i] -= mean;
      energy += samples[i] ** 2;
    }
    if (energy / samples.length < (140 / 32768) ** 2) return false;

    for (let lag = 32; lag <= 180; lag += 2) {
      let cross = 0;
      let first = 0;
      let second = 0;
      for (let i = lag; i < samples.length; i += 2) {
        const a = samples[i];
        const b = samples[i - lag];
        cross += a * b;
        first += a * a;
        second += b * b;
      }
      if (cross > 0.65 * Math.sqrt(first * second)) return true;
    }
    return false;
  }

  function trackVoice(session) {
    const analyser = session.audio.createAnalyser();
    const stride = session.audio.sampleRate / 16000;
    const samples = new Float32Array(640);
    const windowSize = Math.ceil(samples.length * stride);
    analyser.fftSize = 2 ** Math.ceil(Math.log2(windowSize));
    session.audio.createMediaStreamSource(session.stream).connect(analyser);
    const input = new Float32Array(analyser.fftSize);
    session.voiceTimer = setInterval(() => {
      if (active !== session) return;
      analyser.getFloatTimeDomainData(input);
      const offset = input.length - windowSize;
      for (let i = 0; i < samples.length; i++) {
        samples[i] = input[offset + Math.floor(i * stride)];
      }
      session.emit(JSON.stringify({ time: Math.round(performance.now()), voice: hasVoice(samples) }));
    }, 40);
  }

  async function start(withMicrophone, emit) {
    stop();
    const session = { emit };
    active = session;

    try {
      // Resume audio within the gesture that opens the camera permission prompt.
      let audioReady;
      if (withMicrophone) {
        session.audio = new AudioContext();
        audioReady = session.audio.resume().then(() => true, () => false);
      }
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: "user" },
          width: { ideal: 640 },
          height: { ideal: 480 },
        },
        audio: withMicrophone,
      });
      if (active !== session) {
        for (const track of stream.getTracks()) track.stop();
        return null;
      }
      session.stream = stream;
      for (const track of stream.getTracks()) {
        track.addEventListener("ended", () => fail(session,
          "Камера или микрофон отключились. Запусти занятие снова."), { once: true });
      }

      const video = session.video = document.createElement("video");
      video.muted = true;
      video.playsInline = true;
      video.srcObject = stream;
      await video.play();
      if (active !== session) return null;

      visionModule ??= import(asset("vision_bundle.js")).catch((error) => {
        visionModule = null;
        throw error;
      });
      const { FilesetResolver, FaceLandmarker } = await visionModule;
      const runtime = await FilesetResolver.forVisionTasks(asset("wasm"));
      if (active !== session) return null;

      const landmarker = await FaceLandmarker.createFromOptions(runtime, {
        baseOptions: { modelAssetPath: asset("face_landmarker.task") },
        runningMode: "VIDEO",
        numFaces: 2,
        outputFaceBlendshapes: true,
      });
      if (active !== session) {
        landmarker.close();
        return null;
      }
      session.landmarker = landmarker;

      if (withMicrophone) {
        if (!await audioReady) throw new Error("Could not start audio");
        if (active !== session) return null;
        trackVoice(session);
      }
      trackFace(session);
      return null;
    } catch (error) {
      if (active !== session) return null;
      stop();
      if (error.name === "NotAllowedError") {
        return "Разреши камеру и, если нужен звук, микрофон в настройках этого сайта.";
      }
      if (error.name === "NotFoundError" || error.name === "NotReadableError") {
        return "Подключи камеру и микрофон или закрой приложение, которое их использует.";
      }
      return "Не удалось запустить занятие. Проверь камеру и обнови страницу.";
    }
  }

  function sample() {
    stop();
    return new Promise((resolve) => {
      const audio = new Audio(asset("vowel_a.wav"));
      const finish = (success) => {
        if (playing?.audio !== audio) return;
        playing = null;
        audio.pause();
        resolve(success);
      };
      playing = { audio, finish };
      audio.addEventListener("ended", () => finish(true), { once: true });
      audio.addEventListener("error", () => finish(false), { once: true });
      audio.play().catch(() => finish(false));
    });
  }

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) stop();
  });
  window.addEventListener("pagehide", stop);

  window.artikidsCapture = {
    available: () => window.isSecureContext && !!navigator.mediaDevices?.getUserMedia,
    start,
    stop,
    sample,
  };
})();
