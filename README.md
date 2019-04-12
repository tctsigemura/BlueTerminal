# BluetoothTerminal
TeC7b以降に搭載されたMicrochip社のRN4020 Bluetooth Low Energy Moduleと
MLDP(Microchip Low Energy Data Profile)を使用して通信するmacOS用のプログラム．

## RN4020 初期化
TeC7b(Tokuyama Educational Computer Ver.7b)以降に搭載されたRN4020は，
次の操作をすることで工場出荷時の状態にリセットすることができる．
RN4020がシリアル通信でコントロールできなくなった場合に実施する．
1. TeC7のJ1ピンにジャンパを二本同時に横向きに差し込む．
2. TeC7に電源を投入し10秒待つ．
3. 電源を切断する．

## RN4020 初期設定（スクリプト使用の場合）
1. TeC7bのジャンパをDEMO1に設定し，MacとUSBケーブルで接続する．　　
2. setupRN4020.sh を実行する
<pre>
$ ./setuRN4020.sh
your name(Within 8 characters): MyName      // MyNameはRN4020に付ける名前
Please wait 5 seconds...
$                                           // 設定完了
</pre>

## RN4020 初期設定（手動の場合）
1. CoolTermをインストルする．
2. TeC7bのジャンパをDEMO1に設定し，MacとUSBケーブルで接続する．　　
3. CoolTermを起動し，以下のように設定する．
  <pre>  [options] → [Serial Port] → [Port] → TeC7bを接続しているUSB Serialポートを選択
  [options] → [Terminal] → [Enter Key Emulation] → CRを選択 </pre>
4. CoolTermに'+'とEnterキーを入力する．Echo Onと出力されれば，接続成功．
5. CoolTermに以下のコマンドを打ち込む．
  <pre>  SF,2           // 工場出荷状態までリセット
  SR,32104C00    // RN4020起動時に自動アドバタイズおよびMLDPモードとして動作するように設定
  SN,MyName      // RN4020に名前を設定
  SP,0           // RN4020の送信パワーを最低（-19.1dBm）に設定
  R,1            // 再起動 </pre>  
  ※ RN4020が正常に動作していればSF，SRに対して`AOK`と返ってくる．`R,1`の実行後，`CMD`が表示されると設定が終了する．

## インストール
`bin`ディレクトリに移動し`sudo make install`を実行する．
`/usr/local/bin`ディレクトリに`blueterm`,`BlueTerminal`がインストールされる．
<pre>
$ cd bin
$ sudo make install
Password:
install -d -m 755 /usr/local/bin
install -m 755 blueterm /usr/local/bin
install -m 755 BlueTerminal /usr/local/bin
$
</pre>

## 使用方法

### 接続先を一覧から選択する場合
ターミナルで`blueterm`を実行する．
<pre>
$ blueterm                                 // 起動する
周辺のTeCをスキャンします．
接続するTeCを番号で選択して下さい．
~. : プログラム終了
1: MyName                                  // 接続できる候補が表示される
2: HisName
1                                          // 接続先を番号で選択する
"MyName"へ接続しました．                   // 接続完了
</pre>

### 接続先を名前で指定する場合
<pre>
$ blueterm MyName                          // 起動する
"sigemura"と名付けられたTeCに接続します．
~. : プログラム終了                        // 接続完了
</pre>

### blueterm 実行中に使用できるコマンド
blueterm を終了する．
  <pre>  ~.         : プログラム終了</pre>
