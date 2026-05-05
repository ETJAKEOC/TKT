HTMLTableRowElement.prototype.insertHeader = function insertHeader() {
  const tableHeader = document.createElement('th');
  this.appendChild(tableHeader);
  return tableHeader;
}

class File {
  constructor(data) {
    this.name = data.name;
    this.size = new FileSize(data.size);
    this.updatedAt = new Date(data.updatedAt);
    this.digest = data.digest;
    this.url = data.url;
    this.version = data.version;
    this.tag = data.tag;

    const [distro, _, scheduler, compiler] = data.name
      .replace('-diet', '')
      .split(/-|\./);

    Object.defineProperty(this, 'distro', { value: distro });
    Object.defineProperty(this, 'scheduler', { value: scheduler });
    Object.defineProperty(this, 'compiler', { value: compiler });
    Object.freeze(this);
  }
}

class FileSize {
  constructor(bytes) {
    if (!Number.isFinite(bytes) || bytes < 0) {
      throw new Error("FileSize must be a non-negative number of bytes");
    }
    this.bytes = bytes;
  }

  valueOf() {
    return this.bytes;
  }

  toString() {
    return this.humanReadable();
  }

  humanReadable() {
    const units = ["B", "KB", "MB", "GB", "TB", "PB"];
    let size = this.bytes;
    let i = 0;

    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }

    return `${size.toFixed(2)} ${units[i]}`;
  }
}

function CopyButton(text, label = 'Copy') {
  const button = document.createElement('button');
  button.className = 'no-select';
  button.textContent = label;

  button.addEventListener('click', () => {
    navigator.clipboard
      .writeText(text)
      .then(() => {
        button.textContent = 'Copied';
        setTimeout(() => (button.textContent = label), 1500);
      })
      .catch(err => {
        console.error('Copy failed:', err);
        button.textContent = 'Failed';
        setTimeout(() => (button.textContent = label), 1500);
      });
  });

  return button;
}

function timeAgo(date) {
  if (!(date instanceof Date)) {
    throw new TypeError('Expected a Date object');
  }

  const now = new Date();
  if (date > now) return 'in the future';

  // Days
  const diffHours = Math.round((now - date) / 3_600_000);
  const diffDays = Math.round(diffHours / 24);
  if (diffDays < 1)
    return 'today';
  if (diffDays < 7)
    return diffDays === 1 ? '1 day ago' : `${diffDays} days ago`;

  // Weeks
  if (diffDays < 30) {
    const weeks = Math.round(diffDays / 7);
    return weeks === 1 ? '1 week ago' : `${weeks} weeks ago`;
  }

  // Months and years (calendar-based)
  const years = now.getFullYear() - date.getFullYear();
  const months = now.getMonth() - date.getMonth() + years * 12;

  if (months < 12)
    return months <= 1 ? '1 month ago' : `${months} months ago`;

  const fullYears = Math.round(months / 12);
  return fullYears === 1 ? '1 year ago' : `${fullYears} years ago`;
}

export class TableFilter {
  constructor(fileList, tableElement, selectElements, populateTable) {
    this.files = fileList;
    this.table = tableElement;
    this.populateTable = populateTable;

    // Select elements
    this.selectVersion   = selectElements.selectVersion;
    this.selectDistro    = selectElements.selectDistro;
    this.selectScheduler = selectElements.selectScheduler;
    this.selectCompiler  = selectElements.selectCompiler;

    // Initial filter state
    this.chosenTag       = fileList[0]?.tag ?? 'all';
    this.chosenDistro    = 'all';
    this.chosenScheduler = 'all';
    this.chosenCompiler  = 'all';

    this.populateSelectElements();
    this.bindEvents();
    this.updateFiles(); // render first pass
  }

  bindEvents() {
    this.selectVersion.addEventListener('change', ({ target }) => {
      this.chosenTag = target.value;
      this.updateFiles();
    });
    this.selectDistro.addEventListener('change', ({ target }) => {
      this.chosenDistro = target.value;
      this.updateFiles();
    });
    this.selectScheduler.addEventListener('change', ({ target }) => {
      this.chosenScheduler = target.value;
      this.updateFiles();
    });
    this.selectCompiler.addEventListener('change', ({ target }) => {
      this.chosenCompiler = target.value;
      this.updateFiles();
    });
  }

  populateSelectElements() {
    const versions = new Map();
    const distros = new Set();
    const schedulers = new Set();
    const compilers = new Set();

    for (let i = 0, n = this.files.length; i < n; i++) {
      const file = this.files[i];
      versions.set(file.tag, file.version);
      distros.add(file.distro);
      schedulers.add(file.scheduler);
      compilers.add(file.compiler);
    }

    for (const [tag, version] of versions) {
      const versionOption = document.createElement('option');
      versionOption.innerText = version;
      versionOption.value = tag;
      this.selectVersion.appendChild(versionOption);
    }

    for (const distro of distros) {
      const distroOption = document.createElement('option');
      distroOption.innerText = distro;
      distroOption.value = distro.toLowerCase();
      this.selectDistro.appendChild(distroOption);
    }

    for (const scheduler of schedulers) {
      const schedulerOption = document.createElement('option');
      schedulerOption.innerText = scheduler;
      schedulerOption.value = scheduler;
      this.selectScheduler.appendChild(schedulerOption);
    }

    for (const compiler of compilers) {
      const compilerOption = document.createElement('option');
      compilerOption.innerText = compiler;
      compilerOption.value = compiler;
      this.selectCompiler.appendChild(compilerOption);
    }
  }

  updateFiles() {
    const filtered = this.files.filter(this.chooseFile);

    this.populateTable(this.table, filtered);
  }

  /*
   * Arrow function is needed in order to not create a
   * new scope for 'this'.
   */
  chooseFile = (file) => {
    return this.chooseTag(file.tag) &&
      this.chooseDistro(file.distro) &&
      this.chooseScheduler(file.scheduler) &&
      this.chooseCompiler(file.compiler);
  }

  chooseTag(tag) {
    return tag === this.chosenTag;
  }

  chooseDistro(distro) {
    return distro.toLowerCase() === this.chosenDistro ||
      this.chosenDistro === 'all';
  }

  chooseScheduler(scheduler) {
    return scheduler === this.chosenScheduler ||
      this.chosenScheduler === 'all';
  }

  chooseCompiler(compiler) {
    return compiler === this.chosenCompiler ||
      this.chosenCompiler === 'all';
  }
}

export async function cachedFetch(url, key, ttl = 3600) { // ttl in seconds
  const now = Date.now();
  const cached = localStorage.getItem(key);

  if (cached) {
    const { timestamp, data } = JSON.parse(cached);
    if (now - timestamp < ttl * 1000) {
      return data; // still fresh
    }
  }

  const data = await fetch(url).then((res) => res.json());

  localStorage.setItem(key, JSON.stringify({ timestamp: now, data }));
  return data;
}

export function getFilesFromReleases(releases) {
  const files = [];

  for (let i = 0, n = releases.length; i < n; i++) {
    const { name: version, tag_name, assets } = releases[i];
    for (let j = 0, m = assets.length; j < m; j++) {
      const { name, size, updated_at, digest, browser_download_url } = assets[j];
      const [distro, _, scheduler, compiler] = name
        .replace('-diet', '')
        .split(/-|\./);

      files.push(new File({
        name,
        size,
        updatedAt: updated_at,
        digest,
        url: browser_download_url,
        version,
        tag: tag_name,
      }));
    }
  }

  return files;
}

export function populateTable(tableElement, fileList) {
  if (!tableElement.tHead) {
    tableElement.createTHead();
    const headerRow = document.createElement('tr');
    tableElement.tHead.appendChild(headerRow);

    headerRow.insertHeader().innerText = 'name';
    headerRow.insertHeader().innerText = 'size';
    headerRow.insertHeader().innerText = 'last updated';
    headerRow.insertHeader().innerText = 'sha256';
  }

  for (let i = tableElement.tBodies.length - 1; i >= 0; i--) {
    const tBody = tableElement.tBodies[i];
    for (let j = tBody.children.length - 1; j >= 0; j--) {
      const row = tBody.children[j];
      tBody.removeChild(row);
    }
    tableElement.removeChild(tBody);
  }

  const tBody = tableElement.createTBody();
  for (let i = 0, n = fileList.length; i < n; i++) {
    const { name, size, updatedAt, digest, url } = fileList[i];

    const row = tBody.insertRow();
    const nameCell = row.insertCell();
    const sizeCell = row.insertCell();
    const dateCell = row.insertCell();
    const digestCell = row.insertCell();

    const dateOptions = {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
      timeZoneName: 'short'
    };

    nameCell.innerHTML = `<a href="${url}">${name}</a>`;

    sizeCell.innerText = size;
    sizeCell.style.textAlign = 'right';

    dateCell.innerText = timeAgo(updatedAt);
    dateCell.title = new Intl.DateTimeFormat('en-US', dateOptions)
      .format(updatedAt);
    dateCell.style.textAlign = 'center';

    const button = new CopyButton(digest.replace('sha256:', ''));
    button.title = digest.replace('sha256:', '');
    digestCell.appendChild(button);
    digestCell.style.textAlign = 'center';
  }
}
