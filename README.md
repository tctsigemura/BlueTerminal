# BlueTerminal(Ver.2)

TeC7b以降に搭載されたMicrochip社のRN4020 Bluetooth Low Energy Moduleと MLDP(Microchip Low Energy Data Profile)を使用して通信するmacOS用のプログラム． RN4020（MLDP）用の一般的な通信ソフトとしても使用できる．

## RN4020 初期化（制御不能になった場合のみ）

TeC7b(Tokuyama Educational Computer Ver.7b)以降に搭載されたRN4020は， 次の操作をすることで工場出荷時の状態にリセットすることができる． RN4020がシリアル通信でコントロールできなくなった場合に実施する．

1. TeC7のJ1ピンにジャンパを二本同時に横向きに差し込む．
2. TeC7に電源を投入し10秒待つ．
3. 電源を切断する．

## RN4020 初期設定（スクリプト使用の場合）

1. TeC7のジャンパをDEMO1に設定し，MacとUSBケーブルで接続する．
2. setupRN4020.sh を実行する

  ```
  % ./setuRN4020.sh
  your name(Within 8 characters): MyName      // MyNameはRN4020に付ける名前
  Please wait 5 seconds...
  %                                           // 設定完了
  ```

## RN4020 初期設定（手動の場合）

1. CoolTermをインストールする．（screenコマンドが使用できる人は不要）
2. TeC7のジャンパをDEMO1に設定し，MacとUSBケーブルで接続する．
3. CoolTermを起動し，以下のように設定する．

  ```
  [options] → [Serial Port] → [Port] → TeC7を接続しているUSB Serialポートを選択
  [options] → [Terminal] → [Enter Key Emulation] → CRを選択
  ```

4. CoolTermに'+'とEnterキーを入力する．Echo Onと出力されれば，接続成功．
5. CoolTermに以下のコマンドを打ち込む．

  ```
  SF,2           // 工場出荷状態までリセット
  SR,32104C00    // RN4020起動時に自動アドバタイズおよびMLDPモードとして動作するように設定
  SN,MyName      // RN4020に名前を設定
  SP,0           // RN4020の送信パワーを最低（-19.1dBm）に設定
  R,1            // 再起動
  ```

  ※ RN4020が正常に動作していればSF，SRに対して`AOK`と返ってくる．`R,1`の実行後，`CMD`が表示されると設定が終了する．

## インストール

注意： 以下は最新(Version 11.5)のXcodeがインストールされたmacOS(10.15.5)でテストしてる． 最新のXcodeをインストールしないと正常に動作しない可能性がある．

配布物のディレクトリに移動し`sudo make install`を実行する． `/usr/local/bin`ディレクトリに`blueterm`,`BlueTerminal`がインストールされる．

```
% sudo make install
Password:
...
install -d -m 755 /usr/local/bin
install -m 755 blueterm /usr/local/bin
install -m 755 BlueTerminal /usr/local/bin
%
```

## 使用方法

以下の手順で接続する． macOSのターミナルを開き使用する．

### ヘルプ

コマンド行引数 -h を付けて起動すると使い方が表示される．

```
% blueterm -h
使い方: blueterm [-b] [-c] [-h] [名前]
        [-b]はTeC7b用のモードです．
        [-c]はTeC7c用のモードです．
        [-h]はこのメッセージを表示します．
        [名前]はTeCの8文字以内の名前です．
        [名前]が不明の場合は[名前]を省略してbluetermを起動します．
        [名前]が省略されるとbluetermは周辺のTeCをスキャンします．
        その場合は，番号でTeCを選択することができます．
```

### 接続先を一覧から選択して接続する場合

ターミナルで`blueterm`を実行する．

```
$ blueterm                                 // 起動する
終了する時は「~.」を入力します．
TeCに.BINファイルを書き込む時は「~:」を入力します．
接続するTeCの番号を入力してください．
1: MyName                                  // 接続できる候補が表示される
2: HisName
1                                          // 接続先を番号で選択する
"MyName"へ接続しました．                   // 接続完了
```

### 接続先を名前で指定して接続する場合

```
$ blueterm MyName                          // 起動する
終了する時は「~.」を入力します．
TeCに.BINファイルを書き込む時は「~:」を入力します．
"MyName"を探します．
"MyName"に接続しました．                   // 接続完了
```

### blueterm 実行中に使用できるコマンド

blueterm を終了する．

```
  ~.         : プログラム終了
  ~:         : .BINファイルをTeCに書き込む
```
