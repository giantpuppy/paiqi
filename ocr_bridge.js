// OCR 桥接：封装 Tesseract.js 调用 + 图片预处理
let ocrWorker = null;
let ocrWorkerReady = false;

async function getWorker() {
  if (!ocrWorker) {
    ocrWorker = await Tesseract.createWorker('chi_sim+eng');
    ocrWorkerReady = true;
  }
  return ocrWorker;
}

// 预初始化 worker
getWorker().catch(e => console.error('OCR worker init failed:', e));

/**
 * 图片预处理：针对"深色背景+浅色文字"的排期表截图优化
 * 步骤：缩放 -> 灰度化 -> 反色判断 -> 二值化 -> 去噪
 */
async function preprocessImage(base64Image) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d', { willReadFrequently: true });

      // 1. 放大 2 倍提升分辨率（手机截图通常较小）
      const scale = 2;
      canvas.width = img.width * scale;
      canvas.height = img.height * scale;
      ctx.scale(scale, scale);
      ctx.drawImage(img, 0, 0);

      // 2. 获取像素数据
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const data = imageData.data;
      const pixelCount = data.length / 4;

      // 3. 灰度化并计算平均亮度
      let totalBrightness = 0;
      const gray = new Uint8Array(pixelCount);

      for (let i = 0, j = 0; i < data.length; i += 4, j++) {
        const g = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
        gray[j] = g;
        totalBrightness += g;
      }

      const avgBrightness = totalBrightness / pixelCount;
      // 平均亮度 < 100 认为是深色背景（需要反色）
      const needInvert = avgBrightness < 100;

      // 4. 计算自适应阈值（Otsu 算法简化版）
      const threshold = computeThreshold(gray, pixelCount);

      // 5. 二值化
      for (let i = 0, j = 0; i < data.length; i += 4, j++) {
        let val = gray[j];
        if (needInvert) {
          val = 255 - val; // 反色：让文字变黑
        }
        // 二值化
        const binary = val > threshold ? 255 : 0;
        data[i] = data[i + 1] = data[i + 2] = binary;
        data[i + 3] = 255; // 完全不透明
      }

      ctx.putImageData(imageData, 0, 0);

      // 6. 轻微锐化（可选）
      // sharpen(ctx, canvas.width, canvas.height);

      resolve({
        dataUrl: canvas.toDataURL('image/png'),
        needInvert,
        threshold,
        avgBrightness: Math.round(avgBrightness)
      });
    };
    img.onerror = reject;
    img.src = base64Image;
  });
}

/**
 * 计算自适应阈值（简化 Otsu）
 */
function computeThreshold(gray, pixelCount) {
  // 构建直方图
  const hist = new Array(256).fill(0);
  for (let i = 0; i < pixelCount; i++) {
    hist[Math.floor(gray[i])]++;
  }

  let sum = 0;
  for (let i = 0; i < 256; i++) {
    sum += i * hist[i];
  }

  let sumB = 0;
  let wB = 0;
  let wF = 0;
  let maxVar = 0;
  let threshold = 127;

  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB === 0) continue;
    wF = pixelCount - wB;
    if (wF === 0) break;

    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const varBetween = wB * wF * (mB - mF) * (mB - mF);

    if (varBetween > maxVar) {
      maxVar = varBetween;
      threshold = t;
    }
  }

  return threshold;
}

window.ocrRecognize = async function(base64Image) {
  try {
    console.log('[OCR] 开始图片预处理...');
    const processed = await preprocessImage(base64Image);
    console.log('[OCR] 预处理完成: 平均亮度=' + processed.avgBrightness +
                ', 反色=' + processed.needInvert +
                ', 阈值=' + processed.threshold);

    // 将预处理后的图片暴露出来，方便调试
    window._lastProcessedImage = processed.dataUrl;

    const worker = await getWorker();
    // 优化参数：PSM=6 假设单一块文本，保留空格，提升中文识别
    await worker.setParameters({
      tessedit_pageseg_mode: '6',
      preserve_interword_spaces: '1',
      tessedit_char_whitelist: '',
    });
    const result = await worker.recognize(processed.dataUrl);
    return result.data.text;
  } catch (e) {
    console.error('OCR failed:', e);
    // 如果 worker 损坏，尝试重建
    if (ocrWorker) {
      try { await ocrWorker.terminate(); } catch (_) {}
      ocrWorker = null;
      ocrWorkerReady = false;
    }
    return '';
  }
};

// 暴露预处理函数供调试
window.ocrPreprocess = preprocessImage;
