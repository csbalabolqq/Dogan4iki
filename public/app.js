const form = document.querySelector("#punishment-form");
const list = document.querySelector("#punishment-list");
const emptyState = document.querySelector("#empty-state");
const statusPill = document.querySelector("#status-pill");
const submitButton = document.querySelector("#submit-button");
const resetButton = document.querySelector("#reset-button");
const searchInput = document.querySelector("#search");

const fields = {
  id: document.querySelector("#punishment-id"),
  type: document.querySelector("#type"),
  language: document.querySelector("#language"),
  from: document.querySelector("#from"),
  to: document.querySelector("#to"),
  date: document.querySelector("#date"),
  reason: document.querySelector("#reason"),
  customReasonWrap: document.querySelector("#custom-reason-wrap"),
  customReason: document.querySelector("#custom-reason")
};

const translations = {
  ru: {
    title: "Панель наказаний",
    siteLanguage: "Язык сайта",
    typeLabel: "Тип",
    dateLabel: "Когда",
    fromLabel: "От кого",
    toLabel: "Кому",
    reasonLabel: "Причина",
    customReasonOption: "Своя причина",
    customReasonLabel: "Своя причина",
    customReasonPlaceholder: "Напиши свою причину",
    customReasonRequired: "Впиши свою причину.",
    fromPlaceholder: "Ник модератора",
    toPlaceholder: "Ник игрока",
    issueButton: "Выдать",
    saveButton: "Сохранить",
    clearButton: "Очистить",
    journalEyebrow: "Журнал",
    latestTitle: "Последние записи",
    searchPlaceholder: "Поиск",
    emptyState: "Пока записей нет.",
    edit: "Редактировать",
    delete: "Удалить",
    confirmDelete: "Удалить наказание для {name}?",
    statusReady: "Готово",
    statusLoading: "Загрузка",
    statusSaving: "Сохраняю",
    statusSending: "Отправляю",
    statusChanged: "Изменено",
    statusIssued: "Выдано",
    statusDeleting: "Удаляю",
    statusDeleted: "Удалено",
    metaFrom: "От кого",
    metaWhen: "Когда",
    metaReason: "Причина",
    typeNames: {
      "Доган": "Доган",
      "Мут": "Мут",
      "Бан": "Бан",
      "Предупреждение": "Предупреждение"
    },
    reasonNames: {
      "Не явка на лекції": "Неявка на лекцию",
      "Рекомендації голови колегії адвокатів і президента": "Рекомендации главы коллегии адвокатов и президента"
    }
  },
  uk: {
    title: "Панель покарань",
    siteLanguage: "Мова сайту",
    typeLabel: "Тип",
    dateLabel: "Коли",
    fromLabel: "Від кого",
    toLabel: "Кому",
    reasonLabel: "Причина",
    customReasonOption: "Власна причина",
    customReasonLabel: "Власна причина",
    customReasonPlaceholder: "Напиши свою причину",
    customReasonRequired: "Впиши свою причину.",
    fromPlaceholder: "Нік модератора",
    toPlaceholder: "Нік гравця",
    issueButton: "Видати",
    saveButton: "Зберегти",
    clearButton: "Очистити",
    journalEyebrow: "Журнал",
    latestTitle: "Останні записи",
    searchPlaceholder: "Пошук",
    emptyState: "Записів поки немає.",
    edit: "Редагувати",
    delete: "Видалити",
    confirmDelete: "Видалити покарання для {name}?",
    statusReady: "Готово",
    statusLoading: "Завантаження",
    statusSaving: "Зберігаю",
    statusSending: "Надсилаю",
    statusChanged: "Змінено",
    statusIssued: "Видано",
    statusDeleting: "Видаляю",
    statusDeleted: "Видалено",
    metaFrom: "Від кого",
    metaWhen: "Коли",
    metaReason: "Причина",
    typeNames: {
      "Доган": "Доган",
      "Мут": "Мут",
      "Бан": "Бан",
      "Предупреждение": "Попередження"
    },
    reasonNames: {
      "Не явка на лекції": "Не явка на лекції",
      "Рекомендації голови колегії адвокатів і президента": "Рекомендації голови колегії адвокатів і президента"
    }
  }
};

const presetReasons = [
  "Не явка на лекції",
  "Рекомендації голови колегії адвокатів і президента"
];

let punishments = [];
let currentLanguage = localStorage.getItem("siteLanguage") || "ru";
if (!translations[currentLanguage]) {
  currentLanguage = "ru";
}
let activeStatus = { key: "statusReady", message: "", mode: "" };

function t(key) {
  return translations[currentLanguage][key] || translations.ru[key] || key;
}

function displayType(value) {
  return translations[currentLanguage].typeNames[value] || value || "";
}

function displayReason(value) {
  return translations[currentLanguage].reasonNames[value] || value || "";
}

function toggleCustomReason() {
  const isCustom = fields.reason.value === "__custom__";
  fields.customReasonWrap.classList.toggle("is-hidden", !isCustom);
  fields.customReason.required = isCustom;
}

function getSelectedReason() {
  if (fields.reason.value === "__custom__") {
    return fields.customReason.value.trim();
  }

  return fields.reason.value;
}

function setReasonValue(reason) {
  if (presetReasons.includes(reason)) {
    fields.reason.value = reason;
    fields.customReason.value = "";
  } else {
    fields.reason.value = "__custom__";
    fields.customReason.value = reason || "";
  }

  toggleCustomReason();
}

function paintStatus() {
  statusPill.textContent = activeStatus.message || t(activeStatus.key);
  statusPill.className = `status-pill${activeStatus.mode ? ` is-${activeStatus.mode}` : ""}`;
}

function setStatus(key, mode = "") {
  activeStatus = { key, message: "", mode };
  paintStatus();
}

function setErrorStatus(message) {
  activeStatus = { key: "", message, mode: "error" };
  paintStatus();
}

function translatePage() {
  document.documentElement.lang = currentLanguage;
  document.title = t("title");

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    element.textContent = t(element.dataset.i18n);
  });

  document.querySelectorAll("[data-i18n-placeholder]").forEach((element) => {
    element.placeholder = t(element.dataset.i18nPlaceholder);
  });

  document.querySelectorAll("[data-type-option]").forEach((option) => {
    option.textContent = displayType(option.value);
  });

  document.querySelectorAll("[data-reason-option]").forEach((option) => {
    option.textContent = displayReason(option.value);
  });

  submitButton.textContent = fields.id.value ? t("saveButton") : t("issueButton");
  paintStatus();
  renderPunishments();
}

function toInputDateValue(date = new Date()) {
  const offset = date.getTimezoneOffset();
  const local = new Date(date.getTime() - offset * 60 * 1000);
  return local.toISOString().slice(0, 16);
}

function formatDate(value) {
  if (!value) {
    return "";
  }

  return new Intl.DateTimeFormat(currentLanguage === "uk" ? "uk-UA" : "ru-RU", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function escapeText(value) {
  return String(value).replace(/[&<>"']/g, (char) => {
    const entities = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    };
    return entities[char];
  });
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json; charset=utf-8" },
    ...options
  });

  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload.message || "Ошибка запроса.");
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

function getVisiblePunishments() {
  const query = searchInput.value.trim().toLowerCase();

  if (!query) {
    return punishments;
  }

  return punishments.filter((item) => {
    return [displayType(item.type), item.from, item.to, displayReason(item.reason), item.date]
      .join(" ")
      .toLowerCase()
      .includes(query);
  });
}

function renderPunishments() {
  const visible = getVisiblePunishments();
  emptyState.classList.toggle("is-hidden", visible.length > 0);

  list.innerHTML = visible
    .map((item) => {
      return `
        <article class="punishment-card">
          <div class="card-top">
            <div>
              <span class="type-badge">${escapeText(displayType(item.type))}</span>
              <h3 class="card-title">${escapeText(item.to)}</h3>
            </div>
            <div class="card-actions">
              <button class="icon-button" type="button" data-action="edit" data-id="${item.id}" title="${t("edit")}" aria-label="${t("edit")}">✎</button>
              <button class="icon-button delete-button" type="button" data-action="delete" data-id="${item.id}" title="${t("delete")}" aria-label="${t("delete")}">×</button>
            </div>
          </div>
          <p class="card-meta"><strong>${t("metaFrom")}:</strong> ${escapeText(item.from)}</p>
          <p class="card-meta"><strong>${t("metaWhen")}:</strong> ${escapeText(formatDate(item.date))}</p>
          <p class="card-reason"><strong>${t("metaReason")}:</strong> ${escapeText(displayReason(item.reason))}</p>
        </article>
      `;
    })
    .join("");
}

function resetForm() {
  form.reset();
  fields.id.value = "";
  fields.type.value = "Доган";
  fields.reason.value = "Не явка на лекції";
  fields.customReason.value = "";
  toggleCustomReason();
  fields.date.value = toInputDateValue();
  submitButton.textContent = t("issueButton");
}

function fillForm(item) {
  fields.id.value = item.id;
  fields.type.value = item.type || "Доган";
  fields.from.value = item.from || "";
  fields.to.value = item.to || "";
  fields.date.value = item.date || toInputDateValue();
  setReasonValue(item.reason || "Не явка на лекції");
  submitButton.textContent = t("saveButton");
  fields.type.focus();
}

async function loadPunishments() {
  setStatus("statusLoading");
  punishments = await requestJson("/api/punishments");
  renderPunishments();
  setStatus("statusReady", "success");
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const reason = getSelectedReason();

  if (!reason) {
    setErrorStatus(t("customReasonRequired"));
    fields.customReason.focus();
    return;
  }

  const payload = {
    type: fields.type.value,
    language: currentLanguage,
    from: fields.from.value,
    to: fields.to.value,
    date: fields.date.value,
    reason
  };

  const id = fields.id.value;
  submitButton.disabled = true;
  setStatus(id ? "statusSaving" : "statusSending");

  try {
    let result;
    const successStatus = id ? "statusChanged" : "statusIssued";

    if (id) {
      result = await requestJson(`/api/punishments/${id}`, {
        method: "PUT",
        body: JSON.stringify(payload)
      });
    } else {
      result = await requestJson("/api/punishments", {
        method: "POST",
        body: JSON.stringify(payload)
      });
    }

    resetForm();
    await loadPunishments();

    if (result?.discordWarning) {
      setErrorStatus(result.discordWarning);
    } else {
      setStatus(successStatus, "success");
    }
  } catch (error) {
    setErrorStatus(error.message);
  } finally {
    submitButton.disabled = false;
  }
});

list.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-action]");

  if (!button) {
    return;
  }

  const item = punishments.find((punishment) => punishment.id === button.dataset.id);

  if (!item) {
    return;
  }

  if (button.dataset.action === "edit") {
    fillForm(item);
    return;
  }

  if (button.dataset.action === "delete") {
    const confirmed = window.confirm(t("confirmDelete").replace("{name}", item.to));

    if (!confirmed) {
      return;
    }

    setStatus("statusDeleting");

    try {
      const result = await requestJson(`/api/punishments/${item.id}`, { method: "DELETE" });
      await loadPunishments();

      if (result?.discordWarning) {
        setErrorStatus(result.discordWarning);
      } else {
        setStatus("statusDeleted", "success");
      }
    } catch (error) {
      setErrorStatus(error.message);
    }
  }
});

fields.language.addEventListener("change", () => {
  currentLanguage = fields.language.value;
  localStorage.setItem("siteLanguage", currentLanguage);
  translatePage();
});

fields.reason.addEventListener("change", toggleCustomReason);
resetButton.addEventListener("click", resetForm);
searchInput.addEventListener("input", renderPunishments);

fields.language.value = currentLanguage;
resetForm();
translatePage();
loadPunishments().catch((error) => {
  setErrorStatus(error.message);
});




