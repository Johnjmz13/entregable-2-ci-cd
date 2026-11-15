# entregable-2-ci-cd

Taller Entregable 2 del curso de CI/CD: pipeline de CI con Python, GitHub Actions, Docker y SonarCloud para una calculadora web en Flask.

## Integrantes

Texto usado en `AUTOR` (`app/calculadora.py`): **John Jimenez**

| Nombre completo | Usuario de GitHub | Rol |
|---|---|---|
| John Jimenez | [@Johnjmz13](https://github.com/Johnjmz13) | Propietario del repositorio |

Modalidad: individual. Como no hay otro integrante que apruebe, la regla `proteger-main` exige Pull Request y el check `build-and-test`, pero con 0 aprobaciones (GitHub no permite aprobar un PR propio).

## Evidencias

- Pull Request de la sección 9: URL_DEL_PR
- Ejecución fallida por el error intencional: URL_EJECUCION_FALLIDA
- Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

## Respuestas

### 1. ¿Qué ventajas le proporciona a un proyecto el uso de un pipeline de CI?

1. **Los errores se detectan en minutos y no en producción.** Cada push y cada PR ejecutan las pruebas unitarias, de componente y de aceptación. Cuando metí el error en `restar`, el pipeline falló en el paso de pruebas antes de construir nada. Si ese cambio hubiera llegado a `main`, la calculadora habría devuelto resultados incorrectos a cualquier usuario.
2. **La calidad se mide igual para todos los cambios.** Black, Pylint, Flake8, la cobertura mínima del 80% y el Quality Gate de SonarCloud se aplican siempre con las mismas versiones fijadas en `requirements-dev.txt`. No depende de que alguien se acuerde de correr los linters ni de la configuración de cada computador.
3. **Lo que se publica es exactamente lo que se probó.** La imagen se construye una vez, se prueba con Selenium y esa misma imagen, etiquetada con el SHA del commit, se sube a Docker Hub. Eso da trazabilidad (sé qué código hay en cada imagen) y permite volver a una versión anterior si algo sale mal.
4. **`main` siempre queda en un estado desplegable.** Con la regla `proteger-main` nada entra sin PR y sin el check `build-and-test` en verde, así que cualquier commit de `main` se puede desplegar.

### 2. Diferencia entre prueba unitaria, de componente y de aceptación

Uso como ejemplo Zelena, el proyecto en el que trabajo: una aplicación web en React y Node.js que gestiona operaciones de fulfillment y pagos a operadores sobre Stellar.

- **Unitaria:** prueba una función aislada, sin red, base de datos ni servidor. Ejemplo: la función que calcula la comisión de un pago a un operador debe devolver el valor correcto para montos normales, cero y negativos. En este taller son las pruebas de `tests/test_calculadora.py`.
- **De componente:** prueba un componente completo (rutas, validaciones y plantilla o respuesta) sin levantar servidores reales ni depender de servicios externos. Ejemplo: llamar al endpoint `POST /orders` con un cliente de pruebas y verificar que responda 400 si falta un campo y 201 si los datos son válidos, simulando la base de datos. En este taller son las de `tests/test_app.py` con el cliente de pruebas de Flask.
- **De aceptación:** prueba la aplicación como la usaría una persona, en un navegador real y con la app desplegada. Ejemplo: un operador inicia sesión, crea una orden y ve la confirmación en pantalla. En este taller son las de `tests/test_acceptance_app.py` con Selenium, contra el contenedor Docker.

### 3. Steps del workflow

| Step | Qué hace | Para qué |
|---|---|---|
| `Checkout` | Clona el repositorio con todo el historial (`fetch-depth: 0`). | El runner necesita el código; SonarCloud usa el historial para saber qué código es nuevo. |
| `Set up Python` | Instala Python 3.13. | Usar la misma versión que en local y en el `Dockerfile`. |
| `Install dependencies` | Instala `requirements-dev.txt` (que incluye `requirements.txt`). | Tener Flask, los linters y las herramientas de prueba con versiones fijas. |
| `Run Black` | `black app --check`. | Detener el pipeline si hay código sin formatear. |
| `Run Pylint` / `Run Flake8` | Generan `pylint-report.txt` y `flake8-report.txt` con `--exit-zero`. | Los hallazgos no detienen el pipeline: se envían a SonarCloud, que decide con el Quality Gate. Si la herramienta falla, el paso sí falla. |
| `Run Unit and Component Tests` | Ejecuta pytest sin las pruebas de aceptación y con `--cov-fail-under=80`. | Falla si alguna prueba falla o la cobertura total baja del 80%; genera `coverage.xml`. |
| `Build Docker image` | Construye la imagen con la etiqueta `usuario/repositorio:<SHA>`. | Empaquetar la app una sola vez, con un identificador único por commit. |
| `Start container` | Arranca la imagen en el puerto 8000 y espera hasta 30 s a que responda. | Tener la app real corriendo antes de las pruebas de aceptación, sin un `sleep` fijo. |
| `Run Acceptance Tests` | Ejecuta Selenium en Chrome headless contra `http://localhost:8000`. | Validar la imagen que se va a publicar, no solo el código. |
| `Show container logs on failure` | Muestra `docker logs` solo si algo falló. | Diagnosticar por qué la app no arrancó o respondió mal. |
| `Upload Test Reports Artifacts` | Sube cobertura, reportes de pytest y de linters (`if: always()`). | Revisar los reportes aunque el pipeline haya fallado. |
| `SonarCloud Scan` | Envía código y reportes a SonarCloud y espera el Quality Gate. | Bloquear el pipeline si el Quality Gate no es `Passed`. |
| `Login to Docker Hub` | Inicia sesión con `vars.DOCKERHUB_USERNAME` y `secrets.DOCKERHUB_TOKEN` (solo en push a `main`). | Poder publicar sin exponer credenciales. |
| `Push Docker image` | Etiqueta la imagen probada como `latest` y sube las etiquetas SHA y `latest` (solo en push a `main`). | Publicar exactamente la imagen validada, sin reconstruirla. |

### 4. Problemas y aprendizajes

**John Jimenez:**

- Mi Python local era 3.10 y `pip install -r requirements-dev.txt` falló porque `flake8==7.5.0` exige Python 3.11 o superior. Instalé Python 3.13 (la versión del pipeline y del `Dockerfile`) y creé el entorno virtual con ella. Aprendí que fijar versiones exactas también fija la versión mínima de Python.
- `docker build` falló al principio con un error de conexión al daemon porque Docker Desktop no estaba abierto. Lo inicié y la imagen se construyó sin cambios en el `Dockerfile`.
- No tenía Chrome instalado. La primera ejecución de las pruebas de aceptación falló en la primera prueba mientras Selenium Manager descargaba el navegador; las demás pasaron. Al repetirla, las 6 pasaron. En GitHub Actions no pasa porque `ubuntu-latest` ya trae Chrome.
- Como trabajé solo, no podía aprobar mi propio PR. Configuré la regla con PR obligatorio y el check `build-and-test`, sin aprobaciones requeridas.

### 5. Ventajas de probar y publicar la misma imagen Docker

- **Se prueba lo que realmente se entrega.** Validar solo el código no detecta errores de empaquetado: un archivo que no se copia en el `Dockerfile`, una dependencia que está en `requirements-dev.txt` pero no en `requirements.txt`, o Gunicorn mal configurado. Las pruebas de Selenium contra el contenedor sí los detectan.
- **No hay diferencias entre lo probado y lo publicado.** Si se reconstruyera la imagen para publicarla, podría cambiar la imagen base o alguna dependencia entre una construcción y otra. Publicando la misma imagen, lo que pasó las pruebas es lo que llega a Docker Hub.
- **Trazabilidad y rollback.** La etiqueta con el SHA indica de qué commit salió cada imagen; si una versión falla en el Taller 3, se puede desplegar la etiqueta anterior.
- **Mismo comportamiento en cualquier entorno.** La imagen lleva Python, dependencias y comando de arranque, así que funciona igual en mi PC, en el runner y en el servidor.

### 6. Pull Request de la sección 9

**Pruebas agregadas y qué error detectaría cada una:**

- `test_sumar_decimales`: `sumar(0.1, 0.2) == pytest.approx(0.3)`. Detecta que `sumar` convierta a entero o redondee los decimales.
- `test_restar_negativos`: `restar(-5, -3) == -2`. Detecta que `restar` invierta el orden de los operandos o sume en vez de restar (con el error intencional da `-8`).
- `test_multiplicar_negativos`: `multiplicar(-2, -3) == 6`. Detecta un manejo incorrecto del signo.
- `test_index_post_un_numero_invalido`: envía `num1='2'` y `num2='abc'`. Detecta que la app acepte un formulario parcialmente inválido o responda con error 500 en vez de mostrar `Error: Introduce números válidos`.

**Con el error intencional** (`restar` devolviendo `a + b`):

- El pipeline falló en **`Run Unit and Component Tests`**: fallaron `test_restar`, `test_restar_negativos` y `test_index_post_restar`.
- **No se ejecutaron** `Build Docker image`, `Start container`, `Run Acceptance Tests`, `SonarCloud Scan`, `Login to Docker Hub` ni `Push Docker image`. Sí se ejecutaron `Show container logs on failure` y `Upload Test Reports Artifacts`, por sus condiciones `failure()` y `always()`.
- **Cómo se impidió que llegara a `main` y a Docker Hub:** la regla `proteger-main` exige que el check `build-and-test` esté en verde, así que GitHub bloqueó el merge del PR mientras el check estaba fallido. Además, el push a Docker Hub solo ocurre en un push a `main` y si todos los pasos anteriores pasaron; como el PR no se integró y el pipeline se detuvo antes de construir la imagen, no se publicó nada. Al restaurar `return a - b` el pipeline volvió a quedar en verde y solo entonces se pudo hacer el merge.

## Cómo ejecutar

```bash
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements-dev.txt

python -m app.app              # http://localhost:5000

# Pruebas unitarias y de componente (cobertura mínima 80%)
pytest --ignore=tests/test_acceptance_app.py --cov-fail-under=80

# Pruebas de aceptación (con la app en ejecución)
pytest tests/test_acceptance_app.py --no-cov --html=acceptance-report.html
```
