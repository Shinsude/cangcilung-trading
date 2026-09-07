import numpy as np

from config import GRU_EPOCHS, LOOKBACK_WINDOWS


def _to_returns(closes: np.ndarray) -> np.ndarray:
    closes = np.asarray(closes, dtype=np.float64)
    log = np.log(np.maximum(closes, 1e-9))
    return np.diff(log)


def _windowed(returns: np.ndarray, lookback: int):
    xs, ys = [], []
    for i in range(lookback, len(returns)):
        xs.append(returns[i - lookback : i])
        ys.append(returns[i])
    return np.array(xs), np.array(ys)


def _scale(xs: np.ndarray, ys: np.ndarray):
    std = float(np.std(xs) + 1e-8)
    ystd = float(np.std(np.concatenate([ys, xs.reshape(-1)])) + 1e-8)
    return (xs / std, ys / ystd, std, ystd)


def _mlp_forward(x, w1, b1, w2, b2):
    h = np.tanh(x @ w1 + b1)
    out = h @ w2 + b2
    return h, out


def _train(xs, ys, hidden=16, epochs=GRU_EPOCHS, lr=0.01):
    n, lookback = xs.shape
    rng = np.random.default_rng(7)
    w1 = rng.normal(0, 0.1, (lookback, hidden))
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


def _train_and_predict(returns: np.ndarray, lookback: int, epochs: int = GRU_EPOCHS, lr: float = 0.01):
    if len(returns) < lookback + 6:
        return None, 0.5
    xs, ys = _windowed(returns, lookback)
    xscaled, yscaled, xstd, ystd = _scale(xs, ys)

    split = max(1, int(len(xscaled) * 0.7))
    xtr, ytr = xscaled[:split], yscaled[:split]
    xva, yva = xscaled[split:], yscaled[split:]

    w1, b1, w2, b2 = _train(xtr, ytr, epochs=epochs, lr=lr)

    _, pr_tr = _mlp_forward(xtr, w1, b1, w2, b2)
    _, pr_va = _mlp_forward(xva, w1, b1, w2, b2)

    hit = 0.0
    if len(yva) > 0:
        hits = np.sign(pr_va.reshape(-1)) == np.sign(yva)
        hit = float(hits.mean())

    last_window = returns[-lookback:] / xstd
    last_window = last_window.reshape(1, -1)
    _, pred_scaled = _mlp_forward(last_window, w1, b1, w2, b2)
    pred_return = float(pred_scaled[0, 0] * ystd)
    confidence = min(0.95, 0.5 + hit * 0.45)
    return pred_return, confidence


def directional_accuracy(closes: np.ndarray, max_points: int = 72) -> dict:
    """Walk-forward hit rate MLP nyata: train pada setiap titik berjalan, ukur arah prediksi
    vs return aktual berikutnya. Dipakai untuk memvalidasi kekuatan MLP dibanding proxy
    momentum (komponen prediction di backtest memakai momentum, bukan MLP nyata)."""
    returns = _to_returns(closes)
    out = {}
    for lb in LOOKBACK_WINDOWS:
        hits = 0
        cnt = 0
        start = max(lb, len(returns) - max_points, lb + 1)
        for k in range(start, len(returns)):
            seg = returns[max(0, k - 120) : k]
            if len(seg) < lb + 6:
                continue
            pred, _ = _train_and_predict(seg, lb, epochs=30, lr=0.012)
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


def predict(closes: np.ndarray, horizon_hours: int = 6):
    if len(closes) < 40:
        raise ValueError("Not enough price history to build a prediction")
    returns = _to_returns(closes)
    window_returns = (returns[-96:] if len(returns) > 96 else returns)

    preds = []
    confs = []
    for lookback in LOOKBACK_WINDOWS:
        pred_return, conf = _train_and_predict(window_returns, lookback, epochs=50, lr=0.012)
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