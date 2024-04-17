const fs = require("fs");

const { MerkleTree } = require("merkletreejs");

const keccak256 = require("keccak256");

const conf = require("../migration-parameters");

async function generateMerkleRoot() {
  try {
    const network = "development";
    let leaves = {};
    let c = {};

    switch (network) {
      case "development":
        c = { ...conf.development };
        break;
      case "ropsten":
        c = { ...conf.ropsten };
        break;
      case "sepolia":
        c = { ...conf.sepolia };
        break;
      case "mainnet":
        c = { ...conf.mainnet };
        break;
      default:
        break;
    }

    const tree = new MerkleTree(
      leaves,
      keccak256,
      { sort: true }
    );

    fs.writeFileSync("./merkle/tree.json", JSON.stringify(tree))

    fs.writeFileSync("./merkle/root.dat", tree.getHexRoot());

    console.log("Merkle root generated successfully!")
    process.exit();
  } catch (error) {
    console.log(error);
  }
}

generateMerkleRoot()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })
