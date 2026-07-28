import QRCode from 'qrcode';
import fs from 'fs';
import path from 'path';

/**
 * Gera automaticamente um QR Code apenas quando o item é criado.
 */
async function processQRCode(event: any, strapi: any) {
  const { result } = event;

  if (!result) return;
  if (result.qrCodeImage) return;

  const targetId = result.documentId;
  const fileName = `qr-${targetId}.png`;
  const tempPath = path.join('/tmp', fileName);

  try {
    const qrCodeBase64 = await QRCode.toDataURL(targetId);
    const base64Data = qrCodeBase64.replace(/^data:image\/png;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    fs.writeFileSync(tempPath, buffer);

    const uploadedFiles = await strapi
      .plugin('upload')
      .service('upload')
      .upload({
        data: {
          fileInfo: {
            name: fileName,
            alternativeText: `QR Code ${targetId}`,
            caption: `QR Code do item ${targetId}`,
          },
        },
        files: [
          {
            filepath: tempPath,
            originalFilename: fileName,
            mimetype: 'image/png',
            size: buffer.length,
          },
        ],
      });

    const uploadedFile = uploadedFiles?.[0];

    if (!uploadedFile) {
      throw new Error('Falha no upload do QR Code.');
    }

    if (strapi.documents) {
      await strapi.documents('api::item.item').update({
        documentId: result.documentId,
        data: {
          qrCodeImage: uploadedFile.id,
        },
      });
    } else {
      await strapi.entityService.update(
        'api::item.item',
        result.id,
        {
          data: {
            qrCodeImage: uploadedFile.id,
          },
        }
      );
    }

    console.log(`QR Code gerado automaticamente para o item: ${targetId}`);
  } catch (err: any) {
    console.error('Erro ao gerar QR Code:', err.message);
  } finally {
    if (fs.existsSync(tempPath)) {
      fs.unlinkSync(tempPath);
    }
  }
}

export default {
  // Registo do custom field removido completamente daqui
  register({ strapi }: { strapi: any }) {},

  // Mantém apenas o bootstrap do QR Code
  bootstrap({ strapi }: { strapi: any }) {
    console.log('🚀 [INIT] Sistema de Museus: QR automático ativo');

    strapi.db.lifecycles.subscribe({
      models: ['api::item.item'],
      async afterCreate(event) {
        await processQRCode(event, strapi);
      },
    });
  },
};