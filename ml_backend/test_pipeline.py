from services.data_service import data_service
from services.indicators import compute_all
from services.predictor import predict
from services.sentiment import analyze as analyze_sentiment
from services.signal import build_signal

for symbol in ["XAUUSD", "NASDAQ", "AUDUSD"]:
    df = data_service.fetch(symbol)
    print(f"[{symbol}] data rows: {len(df)}")
    ind = compute_all(df)
    print(f"  indicators ok -> RSI {ind['rsi']}, EMA trend {ind['ema']['trend']}, MACD {ind['macd']['cross']}")
    pred = predict(df["Close"].to_numpy())
    print(f"  prediction -> {pred}")
    sent = analyze_sentiment(symbol, pred["next_price"] / df["Close"].iloc[-1] - 1)
    print(f"  sentiment -> {sent['label']} ({sent['source']})")
    sig = build_signal(ind, pred, sent)
    print(f"  signal -> {sig['action']} {sig['strength']} conf={sig['confidence']}")
    print(f"  summary: {sig['summary'][:120]}...")
    print()
print("ALL OK")