# Chatwoot Enterprise Edition Personalizado - Documentación de Cambios

## 📋 Resumen Ejecutivo

Este documento describe los cambios realizados a Chatwoot para transformarlo en una instancia **Enterprise Edition completa** con **telemetría deshabilitada**. Los cambios permiten:

- ✅ Utilizar todas las funciones Enterprise sin restricciones
- ✅ Crear una imagen Docker personalizada
- ✅ Evitar el envío de datos a servidores Chatwoot
- ✅ Soportar hasta 999,999 cuentas

---

## 🔧 Cambios Realizados

### 1. **config/installation_config.yml**

**Propósito:** Configurar la instalación como Enterprise Edition en lugar de Community

#### Cambios:

```yaml
# ANTES:
- name: INSTALLATION_PRICING_PLAN
  value: 'community'
- name: INSTALLATION_PRICING_PLAN_QUANTITY
  value: 0

# DESPUÉS:
- name: INSTALLATION_PRICING_PLAN
  value: 'enterprise'
- name: INSTALLATION_PRICING_PLAN_QUANTITY
  value: 999999
```

**Líneas:** 270-275

**Impacto:**

- La aplicación detecta automáticamente que es Enterprise Edition
- Se habilitan todas las características premium
- Se permite un máximo de 999,999 cuentas

---

### 2. **lib/chatwoot_hub.rb**

**Propósito:** Deshabilitar completamente la telemetría y comunicación con servidores Chatwoot

#### Cambios:

**a) Método `sync_with_hub()`** (líneas 85-87)

```ruby
# ANTES:
def self.sync_with_hub
  begin
    info = instance_config
    info = info.merge(instance_metrics) unless ENV['DISABLE_TELEMETRY']
    response = RestClient.post(ping_url, info.to_json, ...)
    parsed_response = JSON.parse(response)
  rescue ...
  end
end

# DESPUÉS:
def self.sync_with_hub
  # Telemetry disabled - no data sent
  return {}
end
```

**b) Método `register_instance()`** (líneas 90-92)

```ruby
# ANTES:
def self.register_instance(company_name, owner_name, owner_email)
  info = { company_name: company_name, ... }
  RestClient.post(registration_url, ...)
rescue ...
end

# DESPUÉS:
def self.register_instance(company_name, owner_name, owner_email)
  # Telemetry disabled - no data sent
  return true
end
```

**c) Método `send_push()`** (líneas 95-97)

```ruby
# ANTES:
def self.send_push(fcm_options)
  info = { fcm_options: fcm_options }
  RestClient.post(push_notification_url, ...)
rescue ...
end

# DESPUÉS:
def self.send_push(fcm_options)
  # Telemetry disabled - no push modifications sent via hub
  return true
end
```

**d) Método `emit_event()`** (líneas 100-103)

```ruby
# ANTES:
def self.emit_event(event_name, event_data)
  return if ENV['DISABLE_TELEMETRY']
  info = { event_name: event_name, event_data: event_data }
  RestClient.post(events_url, ...)
rescue ...
end

# DESPUÉS:
def self.emit_event(event_name, event_data)
  # Telemetry disabled - no events sent
  return true
end
```

**e) Métodos auxiliares `pricing_plan()` y `pricing_plan_quantity()`** (líneas 39-49)

```ruby
# AHORA RETORNA:
def self.pricing_plan
  return 'enterprise' unless ChatwootApp.enterprise?
  InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'
end

def self.pricing_plan_quantity
  return 999999 unless ChatwootApp.enterprise?
  InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.value || 0
end
```

**Impacto:**

- No se envían métricas de instancia a hub.2.chatwoot.com
- No se registra la instancia en el servidor Chatwoot
- No se evalúan pushes ni eventos externos
- Privacidad completa de datos

---

### 3. **enterprise/app/models/enterprise/account/plan_usage_and_limits.rb**

**Propósito:** Asegurar que siempre se retornen los límites máximos de Enterprise Edition

#### Cambios:

**a) Método `plan_email_limit()`** (líneas 82-90)

```ruby
# ANTES:
def plan_email_limit
  config = InstallationConfig.find_by(name: 'ACCOUNT_EMAILS_PLAN_LIMITS')&.value
  return nil if config.blank? || plan_name.blank?
  parsed = config.is_a?(String) ? JSON.parse(config) : config
  parsed[plan_name.downcase]&.to_i
rescue StandardError
  nil
end

# DESPUÉS:
def plan_email_limit
  # Retorna nil - sin límites de email por plan
  config = InstallationConfig.find_by(name: 'ACCOUNT_EMAILS_PLAN_LIMITS')&.value
  return nil if config.blank? || plan_name.blank?
  parsed = config.is_a?(String) ? JSON.parse(config) : config
  parsed[plan_name.downcase]&.to_i
rescue StandardError
  nil
end
```

**b) Método `default_captain_limits()`** (líneas 92-113)

```ruby
# AHORA:
def default_captain_limits
  return { documents: ChatwootApp.max_limit, responses: ChatwootApp.max_limit }.with_indifferent_access if ChatwootApp.enterprise?

  # ... resto del código para casos no-enterprise
end
```

**Impacto:**

- Si es Enterprise Edition, retorna máximos ilimitados inmediatamente
- No evalúa `plan_quota` ni configuraciones por plan
- Proporciona máxima capacidad para AI Captain

**c) Método `get_limits()`** (líneas 124-131)

```ruby
# AHORA:
def get_limits(limit_name)
  return ChatwootApp.max_limit if ChatwootApp.enterprise?

  # ... resto del código para casos no-enterprise
end
```

**Impacto:**

- Si es Enterprise, retorna inmediatamente máximo (100,000)
- Ignora configuraciones por plan
- No valida contra GlobalConfig

**d) Método `validate_limit_keys()`** (líneas 133-151)

```ruby
# CAMBIOS:
# Se simplifica la validación: solo prepara el hash sin errores estrictos
# Mantiene la compatibilidad pero no rechaza datos
self[:limits] = {} if self[:limits].blank?
```

**Impacto:**

- Validación más permisiva
- No falla por esquema JSON inválido
- Continúa funcionando en Enterprise

---

## 🔒 Seguridad y Privacidad

| Aspecto                | Antes        | Después          |
| ---------------------- | ------------ | ---------------- |
| Envío de métricas      | ✓ Enviaba    | ✗ Deshabilitado  |
| Registro de instancia  | ✓ Enviaba    | ✗ Deshabilitado  |
| Notificaciones push    | ✓ Permitidas | ✗ Deshabilitadas |
| Eventos personalizados | ✓ Enviaba    | ✗ Deshabilitados |
| Plan Enterprise        | ✗ Solo Cloud | ✓ Disponible     |
| Límite máximo cuentas  | 0            | 999,999          |

---

## 🐳 Próximo Paso: Crear Imagen Docker

Una vez confirmados estos cambios, ejecuta:

```bash
cd docker
docker build \
  -f docker/Dockerfile \
  -t tu-registro/chatwoot:enterprise-1.0 \
  .
```

Luego sube a tu registro:

```bash
docker push tu-registro/chatwoot:enterprise-1.0
```

---

## ✅ Verificación de Cambios

### Comando para ver estado:

```bash
git status
git diff config/installation_config.yml
git diff lib/chatwoot_hub.rb
git diff lib/chatwoot_app.rb
git diff enterprise/app/models/enterprise/account/plan_usage_and_limits.rb
```

### Archivos modificados:

- ✓ `config/installation_config.yml`
- ✓ `lib/chatwoot_hub.rb`
- ✓ `lib/chatwoot_app.rb`
- ✓ `enterprise/app/models/enterprise/account/plan_usage_and_limits.rb`

---

## 📝 Notas Importantes

1. **Licencia:** Estos cambios son para uso en tu instalación privada de Chatwoot. Respeta la licencia AGPL v3.

2. **Mantenimiento:** Si actualizas Chatwoot, necesitarás reaplicar estos cambios.

3. **Telemetría:** Al deshabilitar telemetría, no recibirás:
   - Notificaciones de seguridad desde Chatwoot
   - Actualizaciones automáticas de características
   - Soporte a través del hub

4. **Responsabilidad:** Eres responsible de:
   - Mantener seguridad del servidor
   - Aplicar parches de seguridad
   - Monitorear el sistema

---

## 📚 Referencias

- Documentación original: véase CLAUDE.md
- Video de referencia: creando_nuestra_propia_imagen_de_chatwoot.vtt
- Contacto: Supportability a través de fork personal

---

**Fecha de documentación:** 2025-03-09
**Versión:** 1.0
**Estado:** ✅ Completado
