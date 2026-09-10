import numpy as np

from config import GRU_EPOCHS, LOOKBACK_WINDOWS


def _safe(a):
    a = np.asarray(a, dtype=float)
    return np.nan_to_num(a, nan=0.0)


def _to_returns(closes: np.ndarray) -> np.ndarray:
    closes = np.asarray(closes, dtype=np.float64)
    log = np.log(np.maximum(closes, 1e-9))
    return np.diff(log)


def _features(closes: np.ndarray, df=None) -> np.ndarray:
    """Fitur multi-kanal per-bar untuk MLP. Semua kanal dinormalisasi/bounded
    sehingga setara skala (tanpa leakage: baris i hanya memakai data s.d. bar i)."""
    closes = np.asarray(closes, dtype=np.float64)
    n = len(closes)
    rets = np.zeros(n)
    rets[1:] = np.log(np.maximum(closes[1:], 1e-9)) - np.log(np.maximum(closes[:-1], 1e-9))

    cols = [rets]  # 0: return

    if df is not None:
        # 1: RSI(14)/100 - 0.5
        delta = np.diff(closes)
        gain = np.concatenate([[0.0], np.clip(delta, 0, None)])
        loss = np.concatenate([[0.0], np.clip(-delta, 0, None)])
        ag = _safe(pd_ewm(gain))
        al = _safe(pd_ewm(loss))
        rs = np.divide(ag, al, out=np.zeros_like(ag), where=al > 1e-9)
        rsi = 100 - 100 / (1 + np.maximum(rs, 0.0))
        cols.append(np.clip(rsi / 100.0 - 0.5, -0.5, 0.5))

        # 2: MACD histogram ternormalisasi (relatif 1% harga), bounded
        fast = _safe(pd_ewm(closes, span=12))
        slow = _safe(pd_ewm(closes, span=26))
        mline = fast - slow
        sig = _safe(pd_ewm(mline, span=9))
        mhist = mline - sig
        denom = np.maximum(closes * 0.01, 1e-9)
        mhist_n = np.clip(mhist / denom, -1.0, 1.0)
        cols.append(mhist_n)

        # 3: Volume z-score bounded (vs rata2 20 bar sebelumnya)
        if df is not None and "Volume" in df:
            vol = np.asarray(df["Volume"], dtype=float)
            v = np.zeros(n)
            for i in range(20, n):
                v20 = vol[i - 20 : i]
                mv = float(np.mean(v20))
                sv = float(np.std(v20))
                if mv > 0 and sv > 0:
                    v[i] = (vol[i] - mv) / sv
            cols.append(np.clip(v / 2.0, -1.0, 1.0))
        else:
            cols.append(np.zeros(n))

        # 4: Bollinger %B - 0.5
        mid = _safe(pd_sma(closes, 20))
        std = _safe(pd_std(closes, 20))
        upper = mid + 2 * std
        lower = mid - 2 * std
        pctb = np.divide(closes - lower, upper - lower, out=np.zeros(n), where=(upper - lower) > 1e-9)
        cols.append(np.clip(pctb - 0.5, -0.5, 0.5))

        # 5: momentum 5-bar
        mom5 = np.zeros(n)
        mom5[5:] = closes[5:] / np.maximum(closes[:-5], 1e-9) - 1.0
        cols.append(np.clip(mom5 / 0.05, -1.0, 1.0))

        # 6: posisi harga relatif EMA21
        e21 = _safe(pd_ewm(closes, span=21))
        rel = np.divide(closes - e21, np.maximum(e21, 1e-9), out=np.zeros(n), where=e21 > 1e-9)
        cols.append(np.clip(rel / 0.02, -1.0, 1.0))

    F = np.column_stack(cols)
    return F


def pd_ewm(x, span=14):
    out = np.empty_like(x)
    out[0] = x[0]
    alpha = 2.0 / (span + 1.0)
    for i in range(1, len(x)):
        out[i] = alpha * x[i] + (1 - alpha) * out[i - 1]
    return out


def pd_sma(x, span):
    out = np.full_like(x, np.nan)
    cs = np.cumsum(x)
    out[span - 1 :] = (cs[span - 1 :] - np.concatenate([[0.0], cs[: -span]])) / span
    return out


def pd_std(x, span):
    mu = pd_sma(x, span)
    var = pd_sma(np.power(x - np.nan_to_num(mu), 2), span)
    return np.sqrt(np.maximum(var, 0.0))


def _windowed(F: np.ndarray, returns: np.ndarray, lookback: int):
    xs, ys = [], []
    for i in range(lookback, len(returns)):
        xs.append(F[i - lookback : i].reshape(-1))
        ys.append(returns[i])
    return np.array(xs), np.array(ys)


def _scale(xs: np.ndarray, ys: np.ndarray):
    col_std = np.std(xs, axis=0) + 1e-8
    xs_n = xs / col_std
    ystd = float(np.std(np.concatenate([ys, xs_n.reshape(-1)])) + 1e-8)
    return xs_n, ys / ystd, col_std, ystd


def _mlp_forward(x, w1, b1, w2, b2):
    h = np.tanh(x @ w1 + b1)
    out = h @ w2 + b2
    return h, out


def _train(xs, ys, hidden=16, epochs=GRU_EPOCHS, lr=0.01):
    n, in_features = xs.shape
    rng = np.random.default_rng(7)
    w1 = rng.normal(0, 0.1, (in_features, hidden))
    b1 = np.zeros(hidden)
    w2 = rng.normal(0, 0.1, (hidden, 1))
    b2 = np.zeros(1)
    m_w1 = np.zeros_like(w1)
    m_b1 = np.zeros_like(b1)
    m_w2 = np.zeros_like(w2)
    m_b2 = np.zeros_like(b2)
    v_w1 = np.zeros_like(w1)
    v_b1 = np.zeros_like(b1)
    v_w2 = np.zeros_like(w2)
    v_b2 = np.zeros_like(b2)
    b1_ = 0.9
    b2_ = 0.999
    eps = 1e-8

    for step in range(epochs):
        h, out = _mlp_forward(xs, w1, b1, w2, b2)
        dout = (out - ys.reshape(-1, 1)) / n
        dw2 = h.T @ dout
        db2 = dout.sum(axis=0)
        dh = dout @ w2.T
        da = dh * (1 - h ** 2)
        dw1 = xs.T @ da
        db1 = da.sum(axis=0)

        dw1 = np.clip(dw1, -1, 1)
        db1 = np.clip(db1, -1, 1)
        dw2 = np.clip(dw2, -1, 1)
        db2 = np.clip(db2, -1, 1)

        t = step + 1
        b1_t = 1 - b1_ ** t
        b2_t = 1 - b2_ ** t

        m_w1[:] = b1_ * m_w1 + (1 - b1_) * dw1
        v_w1[:] = b2_ * v_w1 + (1 - b2_) * dw1 ** 2
        w1 -= lr * (m_w1 / b1_t) / (np.sqrt(v_w1 / b2_t) + eps)

        m_b1[:] = b1_ * m_b1 + (1 - b1_) * db1
        v_b1[:] = b2_ * v_b1 + (1 - b2_) * db1 ** 2
        b1 -= lr * (m_b1 / b1_t) / (np.sqrt(v_b1 / b2_t) + eps)

        m_w2[:] = b1_ * m_w2 + (1 - b1_) * dw2
        v_w2[:] = b2_ * v_w2 + (1 - b2_) * dw2 ** 2
        w2 -= lr * (m_w2 / b1_t) / (np.sqrt(v_w2 / b2_t) + eps)

        m_b2[:] = b1_ * m_b2 + (1 - b1_) * db2
        v_b2[:] = b2_ * v_b2 + (1 - b2_) * db2 ** 2
        b2 -= lr * (m_b2 / b1_t) / (np.sqrt(v_b2 / b2_t) + eps)

    return w1, b1, w2, b2


def _train_and_predict(F: np.ndarray, returns: np.ndarray, lookback: int, epochs: int = GRU_EPOCHS, lr: float = 0.01, hidden: int = 16):
    if len(returns) < lookback + 6:
        return None, 0.5
    xs, ys = _windowed(F, returns, lookback)
    xs_n, ys_n, col_std, ystd = _scale(xs, ys)

    split = max(1, int(len(xs_n) * 0.7))
    xtr, ytr = xs_n[:split], ys_n[:split]
    xva, yva = xs_n[split:], ys_n[split:]

    w1, b1, w2, b2 = _train(xtr, ytr, hidden=hidden, epochs=epochs, lr=lr)

    _, pr_tr = _mlp_forward(xtr, w1, b1, w2, b2)
    _, pr_va = _mlp_forward(xva, w1, b1, w2, b2)

    hit = 0.0
    if len(yva) > 0:
        hits = np.sign(pr_va.reshape(-1)) == np.sign(yva)
        hit = float(hits.mean())

    last_window = (F[-lookback:].reshape(1, -1) / col_std)
    _, pred_scaled = _mlp_forward(last_window, w1, b1, w2, b2)
    pred_return = float(pred_scaled[0, 0] * ystd)
    confidence = min(0.95, 0.5 + hit * 0.45)
    return pred_return, confidence


def directional_accuracy(closes: np.ndarray, df=None, max_points: int = 48) -> dict:
    """Walk-forward hit rate MLP nyata: train pada setiap titik berjalan, ukur arah prediksi
    vs return aktual berikutnya. Dipakai untuk memvalidasi kekuatan MLP dibanding proxy
    momentum (komponen prediction di backtest memakai momentum, bukan MLP nyata)."""
    returns = _to_returns(closes)
    F = _features(closes, df)
    out = {}
    for lb in LOOKBACK_WINDOWS:
        hits = 0
        cnt = 0
        start = max(lb, len(returns) - max_points, lb + 1)
        for k in range(start, len(returns)):
            seg_rets = returns[max(0, k - 120) : k]
            seg_F = F[max(0, k - 120) : k]
            if len(seg_rets) < lb + 6:
                continue
            pred, _ = _train_and_predict(seg_F, seg_rets, lb, epochs=24, lr=0.012)
            if pred is None:
                continue
            cnt += 1
            if (pred > 0) == (returns[k] > 0):
                hits += 1
        out[lb] = {"samples": int(cnt), "hit_rate": round(hits / cnt, 3) if cnt else 0.5}

    n_samples = sum(v["samples"] for v in out.values())
    total = 0.0
    for v in out.values():
        total += v["hit_rate"] * v["samples"]
    return {"overall": round(total / n_samples, 3) if n_samples else 0.5, "lookbacks": out}


def hp_validation(closes: np.ndarray, df=None, max_points: int = 20) -> dict:
    """Validasi hiperparameter MLP (hidden size & learning rate) walk-forward.
    Hanya untuk laporan kualitas di /model — prediksi live tetap memakai konfigurasi
    standar agar konsisten dan cepat."""
    returns = _to_returns(closes)
    F = _features(closes, df)
    best = None
    best_hr = -1.0
    table = []
    for hidden in (8, 16, 32):
        for lr in (0.008, 0.012, 0.02):
            hits = 0
            cnt = 0
            for lb in LOOKBACK_WINDOWS:
                start = max(lb, len(returns) - max_points, lb + 1)
                for k in range(start, len(returns)):
                    seg_rets = returns[max(0, k - 120) : k]
                    seg_F = F[max(0, k - 120) : k]
                    if len(seg_rets) < lb + 6:
                        continue
                    pred, _ = _train_and_predict(seg_F, seg_rets, lb, epochs=15, lr=lr, hidden=hidden)
                    if pred is None:
                        continue
                    cnt += 1
                    if (pred > 0) == (returns[k] > 0):
                        hits += 1
            hr = round(hits / cnt, 3) if cnt else 0.5
            entry = {"hidden": hidden, "lr": lr, "hit_rate": hr, "samples": int(cnt)}
            table.append(entry)
            if hr > best_hr:
                best_hr = hr
                best = entry
    return {"best": best, "grid": table}


def predict(closes: np.ndarray, df=None, horizon_hours: int = 6):
    if len(closes) < 40:
        raise ValueError("Not enough price history to build a prediction")
    returns = _to_returns(closes)
    F = _features(closes, df)
    window_rets = (returns[-96:] if len(returns) > 96 else returns)
    window_F = (F[-96:] if len(F) > 96 else F)

    preds = []
    confs = []
    for lookback in LOOKBACK_WINDOWS:
        pred_return, conf = _train_and_predict(window_F, window_rets, lookback, epochs=50, lr=0.012)
        if pred_return is not None:
            preds.append(pred_return)
            confs.append(conf)

    if not preds:
        last = closes[-1]
        return {
            "next_price": round(float(last), 6),
            "horizon": f"{horizon_hours}H",
            "direction": "NEUTRAL",
            "confidence": 0.5,
        }

    pred_return = float(np.mean(preds))
    confidence = float(np.mean(confs))
    last_price = float(closes[-1])
    next_price = last_price * np.exp(pred_return)
    direction = "UP" if next_price > last_price else ("DOWN" if next_price < last_price else "NEUTRAL")
    return {
        "next_price": round(next_price, 6),
        "horizon": f"{horizon_hours}H",
        "direction": direction,
        "confidence": round(confidence, 3),
        "ensembles": len(preds),
    }