import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import '../../customer/checkout/ethereum_service.dart';

final client = Web3Client(rpcUrl, Client());
final String ownerprivateKey = "0x6fe38e7aa0e53429a1f41227f4532e9fb640784e7643bd2eda126473e9578d64";
Future<void> confirmDeliveryOnBlockchain(String orderId) async {
  final credentials = EthPrivateKey.fromHex(ownerprivateKey);
  final EthereumAddress contractAddr = EthereumAddress.fromHex(contractAddress);

  final contract = DeployedContract(
    ContractAbi.fromJson(abi, "OrderEscrow"),
    contractAddr,
  );

  final confirmDeliveryFn = contract.function("confirmDelivery");

  await client.sendTransaction(
    credentials,
    Transaction.callContract(
      contract: contract,
      function: confirmDeliveryFn,
      parameters: [orderId],
      maxGas: 300000,
    ),
    chainId: 1337,
  );
}
