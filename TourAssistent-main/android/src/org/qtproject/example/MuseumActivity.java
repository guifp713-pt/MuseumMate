package org.qtproject.example;

import android.os.Bundle;
import android.content.Intent;
import android.nfc.NfcAdapter;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.app.PendingIntent;
import android.os.Parcelable;
import android.util.Log;
import org.qtproject.qt.android.bindings.QtActivity;

public class MuseumActivity extends QtActivity {

    private NfcAdapter mNfcAdapter;
    private PendingIntent mPendingIntent;
    private static final String TAG = "MuseumNFC";

    // 1. Assinatura do método nativo (JNI) que será apanhado pelo C++
    public native void nativeNfcTagRead(String code);

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mNfcAdapter = NfcAdapter.getDefaultAdapter(this);
    }

@Override
protected void onResume() {
    super.onResume();
    if (mNfcAdapter != null) {
        try {
            Intent intent = new Intent(this, MuseumActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);

            // CORREÇÃO CRÍTICA:
            // NFC Foreground Dispatch EXIGE FLAG_MUTABLE no Android 12+ para que o OS possa
            // injetar (anexar) os dados da tag no intent antes de o devolver ao onNewIntent.
            int flags;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                flags = PendingIntent.FLAG_MUTABLE | PendingIntent.FLAG_UPDATE_CURRENT;
            } else {
                flags = PendingIntent.FLAG_UPDATE_CURRENT;
            }

            mPendingIntent = PendingIntent.getActivity(this, 0, intent, flags);

            // Boa prática: Fornecer explicitamente o IntentFilter em vez de null
            android.content.IntentFilter ndefFilter = new android.content.IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED);
            try {
                ndefFilter.addDataType("text/plain"); // Ajusta se o MIME type for diferente, ou usa "*/*"
            } catch (android.content.IntentFilter.MalformedMimeTypeException e) {
                e.printStackTrace();
            }
            android.content.IntentFilter[] filters = new android.content.IntentFilter[] { ndefFilter };

            mNfcAdapter.enableForegroundDispatch(this, mPendingIntent, filters, null);
            Log.d(TAG, "NFC Foreground Dispatch ativado com sucesso.");
        } catch (Exception e) {
            Log.e(TAG, "Erro ao ativar NFC no onResume: " + e.getMessage());
        }
    }
}

    // DESATIVAÇÃO NATIVA: Executada imediatamente quando a Activity perde o foco
    @Override
    protected void onPause() {
        super.onPause();
        if (mNfcAdapter != null) {
            try {
                mNfcAdapter.disableForegroundDispatch(this);
                Log.d(TAG, "NFC Foreground Dispatch desativado nativamente no onPause.");
            } catch (Exception e) {
                Log.e(TAG, "Erro ao desativar NFC no onPause: " + e.getMessage());
            }
        }
    }

    // 2. Interceta a tag NFC mal o Android a deteta (quando a app está aberta)
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);

        if (intent != null && (NfcAdapter.ACTION_NDEF_DISCOVERED.equals(intent.getAction()) ||
                               NfcAdapter.ACTION_TECH_DISCOVERED.equals(intent.getAction()) ||
                               NfcAdapter.ACTION_TAG_DISCOVERED.equals(intent.getAction()))) {
            processNfcIntent(intent);
        }
    }

    // 5. Processamento limpo do Texto NDEF
    private void processNfcIntent(Intent intent) {
        Parcelable[] rawMsgs = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES);
        if (rawMsgs != null && rawMsgs.length > 0) {
            NdefMessage msg = (NdefMessage) rawMsgs[0];
            NdefRecord[] records = msg.getRecords();

            if (records != null && records.length > 0) {
                NdefRecord record = records[0];
                if (record.getTnf() == NdefRecord.TNF_WELL_KNOWN &&
                    java.util.Arrays.equals(record.getType(), NdefRecord.RTD_TEXT)) {
                        try {
                            byte[] payload = record.getPayload();
                            if (payload == null || payload.length == 0) return;

                            int statusByte = payload[0];
                            int languageCodeLength = statusByte & 0x3F;

                            // Validação de segurança crítica
                            if (payload.length < 1 + languageCodeLength) {
                                Log.e(TAG, "Formato de payload NDEF inválido.");
                                return;
                            }

                            String textEncoding = ((statusByte & 0x80) == 0) ? "UTF-8" : "UTF-16";
                            String code = new String(
                                payload,
                                1 + languageCodeLength,
                                payload.length - 1 - languageCodeLength,
                                textEncoding
                            );

                            Log.d(TAG, "NFC Lido com Sucesso: " + code);
                            nativeNfcTagRead(code);

                        } catch (Exception e) {
                            Log.e(TAG, "Erro NDEF: " + e.getMessage());
                        }
                }
            }
        }
    }

    @Override
    protected void onDestroy() {
        try {
            TourAudioService.stopServiceExplicitly();
            android.os.Process.killProcess(android.os.Process.myPid());
        } catch (Exception ignored) {}
        super.onDestroy();
    }
}