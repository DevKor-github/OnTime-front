const fs = require('fs');
const { google } = require('googleapis');

const requiredEnv = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
};

const readReleaseNotes = (filePath) => {
  if (!filePath || !fs.existsSync(filePath)) {
    return undefined;
  }

  const text = fs.readFileSync(filePath, 'utf8').trimEnd();
  if (!text) {
    return undefined;
  }

  return [{ language: 'en-US', text }];
};

const deleteEdit = async (publisher, packageName, editId) => {
  try {
    await publisher.edits.delete({ packageName, editId });
  } catch (error) {
    console.warn(`Unable to delete failed edit ${editId}: ${error.message}`);
  }
};

const main = async () => {
  const packageName = requiredEnv('PACKAGE_NAME');
  const track = requiredEnv('PLAY_TRACK');
  const releaseFile = requiredEnv('RELEASE_FILE');
  const serviceAccount = JSON.parse(requiredEnv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));

  if (!fs.existsSync(releaseFile)) {
    throw new Error(`Release file does not exist: ${releaseFile}`);
  }

  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });
  const insertResponse = await publisher.edits.insert({ packageName });
  const editId = insertResponse.data.id;

  if (!editId) {
    throw new Error('New Google Play edit has no id.');
  }

  console.log(`Created Google Play edit ${editId}`);

  try {
    const tracksResponse = await publisher.edits.tracks.list({
      packageName,
      editId,
    });
    const availableTracks = (tracksResponse.data.tracks || []).map((item) => item.track);
    if (!availableTracks.includes(track)) {
      throw new Error(
        `Track "${track}" is not available. Available tracks: ${availableTracks.join(', ')}`
      );
    }

    console.log(`Uploading ${releaseFile} to track "${track}"`);
    const bundleResponse = await publisher.edits.bundles.upload({
      packageName,
      editId,
      media: {
        mimeType: 'application/octet-stream',
        body: fs.createReadStream(releaseFile),
      },
    });
    const versionCode = bundleResponse.data.versionCode;

    if (!versionCode) {
      throw new Error('Uploaded Android App Bundle did not return a versionCode.');
    }

    console.log(`Uploaded Android App Bundle versionCode ${versionCode}`);

    const release = {
      name: `${process.env.ANDROID_BUILD_NAME || 'Android'} (${versionCode})`,
      status: 'draft',
      versionCodes: [String(versionCode)],
    };
    const releaseNotes = readReleaseNotes(process.env.RELEASE_NOTES_FILE);
    if (releaseNotes) {
      release.releaseNotes = releaseNotes;
    }

    console.log(`Updating track "${track}" with draft release ${release.name}`);
    await publisher.edits.tracks.update({
      packageName,
      editId,
      track,
      requestBody: {
        track,
        releases: [release],
      },
    });

    console.log(`Committing Google Play edit ${editId}`);
    const commitResponse = await publisher.edits.commit({
      packageName,
      editId,
    });

    console.log(`Committed Google Play edit ${commitResponse.data.id}`);
    console.log(`Uploaded draft release versionCode ${versionCode}`);
  } catch (error) {
    await deleteEdit(publisher, packageName, editId);
    const details = error.response?.data ? JSON.stringify(error.response.data) : error.message;
    throw new Error(details);
  }
};

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
