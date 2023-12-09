



# How to

### Getting ready

Create a Metamask account and fund it with Fantom Testnet Opera Faucet using https://faucet.fantom.network/.



Visit https://faucets.chain.link/fantom-testnet and request Testnet LINKs to the same address.



### Installation

Create a parent folder

````
mkdir serial-justice
cd serial-justice
````



Clone the repository

````
git clone git@github.com:flokapi/serial-justice-contracts.git
cd serial-justice-foundry
````



Create an .env file and paste the private key you previously created.

````
PRIVATE_KEY=XXXXXXXXXXXXXXXX
RPC_URL=http://0.0.0.0:8545
SEPOLIA_RPC_URL=XXXXXXXXXXXXXXXX
FANTOM_TESTNET_RPC_URL=https://rpc.ankr.com/fantom_testnet
ETHERSCAN_API_KEY="XXXXXXXXXXXXXXXX"
````



Install the libraries and build the contracts

````
make install
make build
````



### Unit and integration tests

````
make test
````

All tests should pass



### Deployment

Deploy to fantom testnet

````
make deploy ARGS="--network fantom-test"
````

