



# How to

### Getting ready

Create a Metamask account and fund it with Fantom Testnet Opera Faucet using https://faucet.fantom.network/.



Visit https://faucets.chain.link/fantom-testnet and request Testnet LINKs to the same address.



### Installation

````
mkdir serial-justice
cd serial-justice
````



````
git clone ...................
cd serial-justice-foundry
````



Enter the private key of your first account into the `.env` file



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
make deploy --network fantom-test
````





### Simulation

