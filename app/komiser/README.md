# Komiser - Cloud Environment Inspector

Komiser to narzędzie do monitorowania i wizualizacji zasobów AWS.

## Uruchomienie

```bash
cd app/komiser/
docker compose up -d --build
```

Aplikacja dostępna pod adresem: `http://localhost:3001`

## Konfiguracja połączenia z AWS

### Opcja 1 (rekomendowana na platformie) - rola IAM instancji

Wdrożona platforma nie przekazuje do kontenera poświadczeń GitHub Actions ani
statycznych kluczy. Komiser używa domyślnego AWS credential chain i pobiera
tymczasowe poświadczenia z roli IAM przypisanej do EC2.

```bash
docker compose up -d --build
```

Zakres widocznych zasobów jest celowo ograniczony do polityki roli instancji.

### Opcja 2 - przez UI Cloud Accounts

Jeśli kontener jest już uruchomiony, możesz dodać konto ręcznie:

1. Wejdź w **Cloud Accounts** (lub `/cloud-accounts`)
2. Kliknij **Connect Account** → **AWS**
3. Wpisz nazwę, `Access Key ID` i `Secret Access Key`
4. Po zapisaniu Komiser rozpocznie skanowanie

> ⚠️ **Uwaga:** Do szerszego audytu utwórz osobną, dedykowaną rolę auditową z
> minimalnym zakresem. Nie przypisuj `ReadOnlyAccess` do roli EC2 ani nie
> umieszczaj długowiecznych kluczy AWS w pliku `.env`.

## Troubleshooting

| Objaw | Przyczyna | Rozwiązanie |
|-------|-----------|-------------|
| `no EC2 IMDS role found` | Kontener nie ma roli instancji | Uruchom aplikację na wdrożonej EC2 lub skonfiguruj dedykowaną rolę auditową |
| `incorrect costexplorerOutputList` | Brak dostępu do Cost Explorer | Dodaj `aws:ce:*` do polityki IAM |
| `Failed to list IAM users` | Zbyt ograniczona polityka | Dodaj wyłącznie wymagane akcje do dedykowanej roli auditowej |
