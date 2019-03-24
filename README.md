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

## RN4020 初期設定
1. Macにシリアル通信ソフトCoolTermをインストールする．(screenコマンドでも可能)  
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
 
## 使い方
### インストール
`bin`ディレクトリに移動し`sudo make install`を実行する．
`/usr/local/bin`ディレクトリに`blueterm`,`BlueTerminal`がインストールされる．
### 実行方法
ターミナルで`blueterm`を実行する．
### 使用可能コマンド
  <pre>  ~.         : プログラム終了
  ~;         : コマンドモード
  quit       : コマンドモード終了
  sendFile   : 実行形式ファイル(.out, .exe, .bin)の送信   ※コマンドモード時のみ
  disconnect : 通信の切断</pre>

## 開発環境
macOS Mojave(10.14.1)  
Xcode 10.1  
CoolTerm 1.5.0  
Swift 4.2.1
