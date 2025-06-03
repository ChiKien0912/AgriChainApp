import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

final String rpcUrl = "https://f401-115-73-219-17.ngrok-free.app"; // ví dụ: https://abc123.ngrok.io
final String contractAddress = "0x5E11D9f7F4388817C0CE9b5f6A58A934BB7EEF2A";
final String privateKey = "0xcb98f04255297e3437ea1995ae9bb15b0b8a6a3faa73de142c6f5acbd640c459";
final String abi = '''[
    {
      "constant": true,
      "inputs": [],
      "name": "owner",
      "outputs": [
        {
          "name": "",
          "type": "address"
        }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [
        {
          "name": "",
          "type": "bytes32"
        }
      ],
      "name": "orders",
      "outputs": [
        {
          "name": "buyer",
          "type": "address"
        },
        {
          "name": "amount",
          "type": "uint256"
        },
        {
          "name": "isPaid",
          "type": "bool"
        },
        {
          "name": "isDelivered",
          "type": "bool"
        },
        {
          "name": "isRefunded",
          "type": "bool"
        }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": false,
          "name": "buyer",
          "type": "address"
        },
        {
          "indexed": false,
          "name": "amount",
          "type": "uint256"
        }
      ],
      "name": "LogOrderPaid",
      "type": "event"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "orderId",
          "type": "string"
        }
      ],
      "name": "payOrder",
      "outputs": [],
      "payable": true,
      "stateMutability": "payable",
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "orderId",
          "type": "string"
        }
      ],
      "name": "confirmDelivery",
      "outputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "orderId",
          "type": "string"
        }
      ],
      "name": "refund",
      "outputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';

final client = Web3Client(rpcUrl, Client());

Future<void> payOrderToSmartContract(String orderId, double amountInEther) async {
  final credentials = EthPrivateKey.fromHex(privateKey);
  final EthereumAddress contractAddr = EthereumAddress.fromHex(contractAddress);
  final EthereumAddress myAddress = await credentials.extractAddress();
  
  final contract = DeployedContract(
    ContractAbi.fromJson(abi, "OrderEscrow"),
    contractAddr,
  );

  final payOrder = contract.function("payOrder");

  try {
  await client.sendTransaction(
    credentials,
    Transaction.callContract(
      contract: contract,
      function: payOrder,
      parameters: [orderId],
      value: EtherAmount.inWei(BigInt.parse((amountInEther * 1e18).toStringAsFixed(0))),
      maxGas: 300000,
    ),
    chainId: 1337,
  );
  
  print("🟢 Transaction thành công cho orderId: $orderId");
} catch (e) {
  print("🔴 Giao dịch thất bại: $e");
  rethrow; // hoặc throw Exception("Lỗi thanh toán smart contract")
}
}
Future<void> refundOrderOnBlockchain(String orderId) async {
  final credentials = EthPrivateKey.fromHex(privateKey); // của buyer
  final EthereumAddress contractAddr = EthereumAddress.fromHex(contractAddress);

  final contract = DeployedContract(
    ContractAbi.fromJson(abi, "OrderEscrow"),
    contractAddr,
  );

  final refundFn = contract.function("refund");

  await client.sendTransaction(
    credentials,
    Transaction.callContract(
      contract: contract,
      function: refundFn,
      parameters: [orderId],
      maxGas: 300000,
    ),
    chainId: 1337,
  );
}