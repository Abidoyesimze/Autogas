const PinataClient = require("@pinata/sdk");
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

// Types for metadata
interface NFTAttribute {
    trait_type: string;
    value: string | number;
}

interface NFTMetadata {
    name: string;
    description: string;
    image: string;
    properties: {
        type: string;
        tier: string;
    };
    attributes: NFTAttribute[];
}

// Initialize Pinata
const pinata = new PinataClient(
    process.env.PINATA_API_KEY!,
    process.env.PINATA_SECRET_KEY!
);

// Metadata structure
const createMetadata = (imageCID: string, tokenId: number): NFTMetadata => {
    return {
        name: `Autogas NFT #${tokenId}`,
        description: "This is an AutogasNft selling at 100$ purchase more than 100 and you'll be giving discount",
        image: `ipfs://${imageCID}`,
        properties: {
            type: "Autogas",
            tier: "Standard"
        },
        attributes: [
            {
                trait_type: "Category",
                value: "Utility"
            }
        ]
    };
};

async function uploadMetadata(): Promise<string> {
    try {
        // upload image to Pinata with metadata options
        const imageFile = fs.createReadStream(path.join(__dirname, '../assets/Autogas.jpg'));
        const imageUploadResponse = await pinata.pinFileToIPFS(imageFile, {
            pinataMetadata: {
                name: 'Autogas-NFT-Image',
                keyvalues: {
                    type: 'image'
                }
            }
        });
        console.log('Image uploaded to IPFS:', imageUploadResponse.IpfsHash);

        // Create metadata token(s)
        const metadata = createMetadata(imageUploadResponse.IpfsHash, 1); 

        // Save metadata to a temporary file
        const tempMetadataPath = path.join(__dirname, 'metadata.json');
        fs.writeFileSync(tempMetadataPath, JSON.stringify(metadata, null, 2));

        // Upload metadata to Pinata with metadata options
        const metadataFile = fs.createReadStream(tempMetadataPath);
        const metadataUploadResponse = await pinata.pinFileToIPFS(metadataFile, {
            pinataMetadata: {
                name: 'Autogas-NFT-Metadata',
                keyvalues: {
                    type: 'metadata'
                }
            }
        });
        console.log('Metadata uploaded to IPFS:', metadataUploadResponse.IpfsHash);

        // Clean up temporary file
        fs.unlinkSync(tempMetadataPath);

        //  base URI for the contract
        console.log('Use this as your base URI:', `ipfs://${metadataUploadResponse.IpfsHash}/`);

        return metadataUploadResponse.IpfsHash;
    } catch (error) {
        console.error('Error uploading to Pinata:', error);
        throw error;
    }
}

// For multiple tokens
async function uploadMetadataForMultipleTokens(numberOfTokens: number): Promise<string> {
    try {
        
        const imageFile = fs.createReadStream(path.join(__dirname, '../assets/Autogas.jpg'));
        const imageUploadResponse = await pinata.pinFileToIPFS(imageFile, {
            pinataMetadata: {
                name: 'Autogas-NFT-Image',
                keyvalues: {
                    type: 'image'
                }
            }
        });
        
        // Create metadata folder
        const metadataFolder = path.join(__dirname, 'metadata');
        if (!fs.existsSync(metadataFolder)) {
            fs.mkdirSync(metadataFolder);
        }

        // Create metadata for each token
        for (let i = 1; i <= numberOfTokens; i++) {
            const metadata = createMetadata(imageUploadResponse.IpfsHash, i);
            fs.writeFileSync(
                path.join(metadataFolder, `${i}.json`),
                JSON.stringify(metadata, null, 2)
            );
        }

        // Upload entire metadata folder
        const folderUploadResponse = await pinata.pinFromFS(metadataFolder, {
            pinataMetadata: {
                name: 'Autogas-NFT-Collection-Metadata',
                keyvalues: {
                    type: 'collection'
                }
            }
        });
        console.log('Metadata folder uploaded to IPFS:', folderUploadResponse.IpfsHash);

        
        fs.rmdirSync(metadataFolder, { recursive: true });

        return folderUploadResponse.IpfsHash;
    } catch (error) {
        console.error('Error:', error);
        throw error;
    }
}

// Execute the upload
uploadMetadata()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });